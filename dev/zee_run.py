#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""zee_run.py — launch the zee-power-toys app and wait until it is drivable.

Subcommands
  up [--tier t1|t2]   start flutter run, clean stale forwards, wait until BOTH
                      dhu + hud surfaces answer ext.zee.whoami, then print the
                      VM WebSocket URI.  Exits 0 when ready; non-zero on timeout.
  down [--tier t1|t2] stop the running flutter run for the given tier.

T1 (default) — `flutter run -d linux`
  Writes flutter run stdout/stderr to $ZEE_RUN_LOG (default /tmp/zee_run_t1.log).
  No adb involved.  VM URI is discovered from that log file.
  PID is stored in /tmp/zee_run_t1.pid for `down`.

T2 — `flutter run -d emulator-5554`
  Clears stale `adb forward --remove-all` before starting.
  PID stored in /tmp/zee_run_t2.pid.

Typical use
  uv run dev/zee_run.py up           # T1 — ready in ~15 s on a warm cache
  uv run dev/zee_run.py up --tier t2 # T2
  uv run dev/zee_run.py down         # stop T1

Environment
  ZEE_RUN_LOG    path for flutter run log (default /tmp/zee_run_t1.log)
  ZEE_VM_URI     override VM URI (skips discovery; up still waits for surfaces)
  ADB_SERIAL     adb device serial (default emulator-5554)
"""

from __future__ import annotations

import argparse
import asyncio
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

# Reuse discovery + VMClient from zee_drive (same directory).
sys.path.insert(0, os.path.dirname(__file__))
import zee_drive as _z

# ---------------------------------------------------------------------------
# Per-tier config
# ---------------------------------------------------------------------------

_T1_LOG = Path(os.environ.get("ZEE_RUN_LOG", "/tmp/zee_run_t1.log"))
_T1_PID = Path("/tmp/zee_run_t1.pid")
_T2_LOG = Path("/tmp/zee_run_t2.log")
_T2_PID = Path("/tmp/zee_run_t2.pid")

# Canonical current-session URI file — written by `up`, deleted by `down`.
# resolve_ws_uri() in zee_drive reads this (precedence 2, after explicit override).
_VM_URI_FILE = Path("/tmp/zee_vm_uri.txt")

READY_TIMEOUT_S = 120.0   # wait up to 2 min for VM URI to appear in log
SURFACE_TIMEOUT_S = 60.0  # separate fresh timeout for both surfaces to answer
POLL_INTERVAL_S = 1.0


def _tier_files(tier: str) -> tuple[Path, Path]:
    """Return (log_path, pid_path) for the given tier."""
    return (_T1_LOG, _T1_PID) if tier == "t1" else (_T2_LOG, _T2_PID)


# ---------------------------------------------------------------------------
# adb helpers (T2 only)
# ---------------------------------------------------------------------------

def _adb(*args: str, check: bool = False) -> subprocess.CompletedProcess:
    serial = _z.DEFAULT_SERIAL
    return subprocess.run(
        ["adb", "-s", serial, *args],
        check=check, capture_output=True, text=True, timeout=30,
    )


def _clear_stale_forwards() -> None:
    """Remove all adb port forwards (stale forwards from previous sessions pile up)."""
    r = _adb("forward", "--remove-all")
    if r.returncode == 0:
        print("[zee_run] cleared stale adb forwards")
    else:
        # Non-fatal — may not have adb or no device attached.
        pass


# ---------------------------------------------------------------------------
# Surface readiness poll
# ---------------------------------------------------------------------------

async def _wait_for_both_surfaces(ws_uri: str, timeout_s: float = READY_TIMEOUT_S) -> bool:
    """Return True once both dhu+hud surfaces answer ext.zee.whoami, else False."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            async def probe(c: _z.VMClient) -> dict[str, str]:
                surface_map: dict[str, str] = {}
                isos = await c.isolates()
                for iso in isos:
                    try:
                        res = await c.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
                        surf = res.get("surface", "") if isinstance(res, dict) else ""
                        if surf:
                            surface_map[surf] = iso["id"]
                    except Exception:
                        pass
                return surface_map

            surface_map = await _z._with_client(ws_uri, probe)
            if "dhu" in surface_map and "hud" in surface_map:
                return True
        except Exception:
            pass  # VM service not up yet — keep polling
        await asyncio.sleep(POLL_INTERVAL_S)
    return False


# ---------------------------------------------------------------------------
# up
# ---------------------------------------------------------------------------

def cmd_up(tier: str) -> int:
    log_path, pid_path = _tier_files(tier)

    # --- stop any stale process -------------------------------------------------
    if pid_path.exists():
        try:
            old_pid = int(pid_path.read_text().strip())
            os.kill(old_pid, signal.SIGTERM)
            print(f"[zee_run] stopped stale process pid={old_pid}")
            time.sleep(1.0)
        except (ProcessLookupError, ValueError):
            pass
        pid_path.unlink(missing_ok=True)

    # --- clear stale log so discovery reads only the new session's URI ---------
    log_path.unlink(missing_ok=True)

    # --- T2: clear stale adb forwards ------------------------------------------
    if tier == "t2":
        _clear_stale_forwards()

    # --- build flutter run command ---------------------------------------------
    if tier == "t1":
        cmd = ["flutter", "run", "-d", "linux"]
    else:
        cmd = ["flutter", "run", "-d", _z.DEFAULT_SERIAL]

    print(f"[zee_run] starting: {' '.join(cmd)}")
    print(f"[zee_run] log → {log_path}")

    log_fh = log_path.open("w")
    proc = subprocess.Popen(
        cmd,
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        cwd=Path(__file__).parent.parent,  # repo root
        start_new_session=True,            # detach from our process group
    )
    pid_path.write_text(str(proc.pid))
    print(f"[zee_run] pid={proc.pid}  (stored in {pid_path})")

    # --- wait for VM URI in the log --------------------------------------------
    print(f"[zee_run] waiting for VM service URI in {log_path} …")
    deadline = time.monotonic() + READY_TIMEOUT_S
    ws_uri: str | None = None
    while time.monotonic() < deadline:
        ws_uri = _z._scan_flutter_run_log_for_vm_uri(str(log_path))
        if ws_uri:
            ws_uri = _z._normalize_ws_uri(ws_uri)
            print(f"[zee_run] VM service: {ws_uri}")
            break
        # Check if flutter run died early
        if proc.poll() is not None:
            print(f"[zee_run] flutter run exited early (rc={proc.returncode}); "
                  f"check {log_path}", file=sys.stderr)
            return 1
        time.sleep(POLL_INTERVAL_S)
    else:
        print(f"[zee_run] timed out waiting for VM URI in {log_path}", file=sys.stderr)
        return 1

    # --- persist URI so driving tools find the current session without --vm-uri --
    _VM_URI_FILE.write_text(ws_uri)
    print(f"[zee_run] URI persisted → {_VM_URI_FILE}")

    # --- wait for both dhu + hud surfaces to answer whoami --------------------
    # Use a fresh dedicated timeout so a long cold build does not starve the
    # surface-readiness wait (FIX 3).
    print("[zee_run] waiting for both dhu + hud surfaces …")
    ready = asyncio.run(_wait_for_both_surfaces(ws_uri, timeout_s=SURFACE_TIMEOUT_S))
    if not ready:
        print("[zee_run] timed out waiting for both surfaces", file=sys.stderr)
        return 1

    print(f"[zee_run] READY — both surfaces up")
    print(f"[zee_run] VM URI: {ws_uri}")
    print(f"\nExport for other tools (optional — driving tools read {_VM_URI_FILE} automatically):")
    print(f"  export ZEE_VM_URI='{ws_uri}'")
    return 0


# ---------------------------------------------------------------------------
# down
# ---------------------------------------------------------------------------

def cmd_down(tier: str) -> int:
    _, pid_path = _tier_files(tier)
    if not pid_path.exists():
        print(f"[zee_run] no PID file for tier {tier} — nothing to stop")
        return 0
    try:
        pid = int(pid_path.read_text().strip())
        # Kill the entire process group so dart/gradle children don't orphan
        # (up launched flutter run with start_new_session=True).
        try:
            pgid = os.getpgid(pid)
            os.killpg(pgid, signal.SIGTERM)
            print(f"[zee_run] sent SIGTERM to pgid={pgid} (pid={pid})")
        except ProcessLookupError:
            print(f"[zee_run] process already gone")
            pgid = None
        # Wait briefly for clean exit, then escalate.
        if pgid is not None:
            for _ in range(20):
                try:
                    os.kill(pid, 0)
                    time.sleep(0.25)
                except ProcessLookupError:
                    break
            else:
                try:
                    os.killpg(pgid, signal.SIGKILL)
                    print(f"[zee_run] escalated to SIGKILL for pgid={pgid}")
                except ProcessLookupError:
                    pass
    except (ValueError, ProcessLookupError):
        print(f"[zee_run] process already gone")
    pid_path.unlink(missing_ok=True)
    # Remove canonical URI file so stale URIs don't shadow a future session.
    _VM_URI_FILE.unlink(missing_ok=True)
    if tier == "t2":
        _clear_stale_forwards()
    print(f"[zee_run] done")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Launch the zee-power-toys app and wait until it is drivable."
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    up_p = sub.add_parser("up", help="start flutter run and wait for both surfaces")
    up_p.add_argument("--tier", choices=["t1", "t2"], default="t1",
                      help="target tier (default: t1)")

    dn_p = sub.add_parser("down", help="stop the running flutter run for a tier")
    dn_p.add_argument("--tier", choices=["t1", "t2"], default="t1",
                      help="target tier (default: t1)")

    args = p.parse_args(argv)
    if args.cmd == "up":
        return cmd_up(args.tier)
    elif args.cmd == "down":
        return cmd_down(args.tier)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""zee_run.py — launch the zee-power-toys app and wait until it is drivable.

Subcommands
  preflight [--tier t1|t2] [--fix]
                      T2-specific device-readiness checks that must be true
                      BEFORE `flutter run` starts (auto-run by `up --tier t2`,
                      with --fix implied, so the launch is deterministic):
                        - adb reachable
                        - overlay_display_devices == "1024x576/213"
                        - a secondary display actually resolves at that
                          geometry (dumpsys display)
                        - hudEnabled read from the persisted config (report
                          only; not a preflight failure)
                      --fix repairs a wrong/missing overlay_display_devices
                      setting and polls dumpsys display until the secondary
                      display reappears (changing the setting destroys and
                      recreates the display, so this must happen BEFORE
                      flutter run, never after).
  up [--tier t1|t2] [--no-self-heal]
                      start flutter run, clean stale forwards, wait until BOTH
                      dhu + hud surfaces answer ext.zee.whoami, then print the
                      VM WebSocket URI.  Exits 0 when ready; non-zero on timeout.
                      T2: runs `preflight --fix` first — a missing overlay
                      display means the HUD engine never spawns and `up`
                      times out at 60s with no useful message otherwise.
                      Self-heal (T2, unless --no-self-heal): if after ~20s
                      only the dhu surface has answered and its own whoami
                      reports hudEnabled=false, `up` is trapped forever
                      (setupHud's native-side gate skips the HUD engine
                      entirely) — so `up` sets hudEnabled=true via
                      ext.zee.setConfig, then runs `down`+`up` ONCE more
                      (guarded so it can never loop) instead of hanging for
                      the full 60s budget with no recovery.
  down [--tier t1|t2] stop the running flutter run for the given tier.  Also
                      `am force-stop`s the on-device app for T2 (safe here:
                      the host-side `flutter run` process is already dead by
                      this point) — the pgid kill alone leaves the app
                      process running on the device.
  keepalive [--tier t2] [--max-misses 2] [--no-restart]
                      Mid-slice T2 health pulse (0094 SI emu-kill harden).
                      Runs `adb get-state` against ADB_SERIAL. On success,
                      clears the consecutive-miss counter. On failure,
                      increments it; after `--max-misses` consecutive misses
                      (default 2), stops any live T2 flutter session, cold-
                      boots the AVD (`ZEE_AVD`, default Tablet_Android_12L),
                      waits until `get-state` returns `device`, then runs
                      `preflight --fix`. Caller must re-run `up --tier t2`
                      after a restart. Pass `--no-restart` to only count
                      misses (useful for dry diagnosis).

T1 (default) — `flutter run -d linux` (or `-d macos` on Darwin)
  Writes flutter run stdout/stderr to $ZEE_RUN_LOG (default /tmp/zee_run_t1.log).
  No adb involved.  VM URI is discovered from that log file.
  PID is stored in /tmp/zee_run_t1.pid for `down`.

T2 — `flutter run -d emulator-5554`
  Clears stale `adb forward --remove-all` before starting.
  PID stored in /tmp/zee_run_t2.pid.

Typical use
  uv run dev/zee_run.py preflight --tier t2 --fix  # optional standalone check
  uv run dev/zee_run.py up                         # T1 — ready in ~15 s on a warm cache
  uv run dev/zee_run.py up --tier t2               # T2
  uv run dev/zee_run.py keepalive --tier t2        # mid-slice pulse (QA/beta)
  uv run dev/zee_run.py down                        # stop T1
  # Hung install / wedged flutter run on T2:
  #   uv run dev/zee_run.py down --tier t2 && uv run dev/zee_run.py up --tier t2

Environment
  ZEE_RUN_LOG    path for flutter run log (default /tmp/zee_run_t1.log)
  ZEE_VM_URI     override VM URI (skips discovery; up still waits for surfaces)
  ADB_SERIAL     adb device serial (default emulator-5554)
  ZEE_AVD        AVD name for keepalive restart (default Tablet_Android_12L)
  ANDROID_HOME   SDK root (emulator binary at $ANDROID_HOME/emulator/emulator)

Session URI files (QA3-5 fix — see docs/issues/BACKLOG.md)
  Each tier gets its own /tmp/zee_vm_uri_<tier>.txt (written by `up`, removed
  by `down`) instead of one shared file, so a T2 launch no longer shadows a
  live T1 session.  dev/zee_drive.py's resolve_ws_uri() liveness-probes any
  file-sourced URI (`getVersion`) and deletes it on failure instead of
  handing back a dead port that would hang the caller's first real RPC.
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
from typing import Any

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

READY_TIMEOUT_S = 120.0   # wait up to 2 min for VM URI to appear in log
SURFACE_TIMEOUT_S = 60.0  # separate fresh timeout for both surfaces to answer
SELF_HEAL_CHECK_S = 20.0  # first checkpoint: diagnose the hudEnabled trap here
POLL_INTERVAL_S = 1.0

EXPECTED_OVERLAY = "1024x576/213"
EXPECTED_HUD_W = 1024
EXPECTED_HUD_H = 576

# keepalive (0094) — mid-slice adb get-state pulse + emu restart after N misses
_KEEPALIVE_MISS_FILE = Path("/tmp/zee_keepalive_t2.misses")
KEEPALIVE_MAX_MISSES = 2
EMU_BOOT_TIMEOUT_S = 180.0
DEFAULT_AVD = os.environ.get("ZEE_AVD", "Tablet_Android_12L")


def _tier_files(tier: str) -> tuple[Path, Path]:
    """Return (log_path, pid_path) for the given tier."""
    return (_T1_LOG, _T1_PID) if tier == "t1" else (_T2_LOG, _T2_PID)


def _vm_uri_file(tier: str) -> Path:
    return Path(_z.vm_uri_file(tier))


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
# preflight — T2 device-readiness checks that must be true BEFORE flutter run
# ---------------------------------------------------------------------------

def cmd_preflight(tier: str, fix: bool, quiet: bool = False) -> tuple[bool, dict[str, Any]]:
    """Run device-readiness checks. Returns (ok, result_dict).

    T1 has no adb/display surface to check — reports pass=True trivially.
    """
    result: dict[str, Any] = {"tier": tier}

    if tier == "t1":
        result["note"] = "T1 desktop has no adb/overlay-display surface — nothing to preflight"
        result["pass"] = True
        return True, result

    def _log(msg: str) -> None:
        if not quiet:
            print(f"[zee_run:preflight] {msg}")

    # --- adb reachable -------------------------------------------------
    devices = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=15)
    reachable = any(
        line.startswith(_z.DEFAULT_SERIAL) and "device" in line
        for line in devices.stdout.splitlines()
    )
    result["adbReachable"] = reachable
    _log(f"adb reachable ({_z.DEFAULT_SERIAL}): {reachable}")
    if not reachable:
        result["pass"] = False
        result["remedy"] = (
            f"adb device {_z.DEFAULT_SERIAL!r} not reachable — check `adb devices` "
            "and that the emulator/device is running"
        )
        return False, result

    # --- overlay_display_devices setting --------------------------------
    r = _adb("shell", "settings", "get", "global", "overlay_display_devices")
    current = (r.stdout or "").strip()
    overlay_ok = current == EXPECTED_OVERLAY
    result["overlayDisplayDevicesBefore"] = current
    _log(f"overlay_display_devices = {current!r} (want {EXPECTED_OVERLAY!r}): {overlay_ok}")

    def _display_resolves() -> bool:
        # Pre-launch-safe: resolve_hud_display()'s DisplayViewport parsing
        # needs a Presentation already attached (i.e. flutter run's HUD
        # engine), which does not exist yet at preflight time — see
        # overlay_display_geometry()'s docstring.
        info = _z.overlay_display_geometry(serial=_z.DEFAULT_SERIAL)
        return info is not None and info["w"] == EXPECTED_HUD_W and info["h"] == EXPECTED_HUD_H

    display_ok = overlay_ok and _display_resolves()

    if not display_ok and fix:
        # Covers both failure shapes: the setting itself is wrong/empty, AND
        # the setting already reads correctly but the display never actually
        # materialized (observed live: `settings put` with an unchanged value
        # does not reliably re-fire display creation). Force a clear ->
        # re-apply cycle either way so --fix is a real recreate, not a no-op
        # write.
        _log(f"--fix: clearing then re-setting overlay_display_devices to {EXPECTED_OVERLAY!r}")
        _adb("shell", "settings", "put", "global", "overlay_display_devices", "")
        time.sleep(1.0)
        _adb("shell", "settings", "put", "global", "overlay_display_devices", EXPECTED_OVERLAY)
        # Changing the setting destroys/recreates the display — poll dumpsys
        # display until the new one actually appears at the expected geometry.
        deadline = time.monotonic() + 15.0
        while time.monotonic() < deadline:
            if _display_resolves():
                display_ok = True
                overlay_ok = True
                break
            time.sleep(1.0)
        r2 = _adb("shell", "settings", "get", "global", "overlay_display_devices")
        current = (r2.stdout or "").strip()
        overlay_ok = overlay_ok or current == EXPECTED_OVERLAY
        result["fixed"] = display_ok
        _log(f"after --fix: overlay_display_devices = {current!r}; recovered: {display_ok}")

    result["overlayDisplayDevices"] = current
    result["overlayOk"] = overlay_ok
    if not overlay_ok:
        result["pass"] = False
        result["remedy"] = (
            f'adb shell settings put global overlay_display_devices "{EXPECTED_OVERLAY}" '
            "(then re-run `preflight --fix`, or `up --tier t2` which runs preflight "
            "automatically)"
        )
        return False, result

    # --- secondary display resolves at the expected geometry ------------
    info = _z.overlay_display_geometry(serial=_z.DEFAULT_SERIAL)
    result["hudDisplay"] = info if info is not None else {"error": "no Overlay display device found"}
    result["displayOk"] = display_ok
    _log(f"secondary display resolves at expected geometry: {display_ok}")
    if not display_ok:
        result["pass"] = False
        result["remedy"] = (
            f'adb shell settings put global overlay_display_devices "{EXPECTED_OVERLAY}"'
        )
        return False, result

    # --- hudEnabled from persisted config (report only) ------------------
    hud_enabled = _z.read_persisted_hud_enabled(serial=_z.DEFAULT_SERIAL)
    result["hudEnabled"] = hud_enabled
    _log(f"persisted hudEnabled: {hud_enabled!r}")

    result["pass"] = True
    return True, result


# ---------------------------------------------------------------------------
# Surface readiness poll (with hudEnabled diagnosis for self-heal)
# ---------------------------------------------------------------------------

async def _probe_surfaces_once(ws_uri: str) -> dict[str, dict[str, Any]]:
    """One-shot probe: return {surface: whoami_result} for every isolate that answers."""
    async def probe(c: _z.VMClient) -> dict[str, dict[str, Any]]:
        out: dict[str, dict[str, Any]] = {}
        try:
            isos = await c.isolates()
        except Exception:
            return out
        for iso in isos:
            try:
                res = await c.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
                if isinstance(res, dict) and res.get("surface"):
                    out[res["surface"]] = res
            except Exception:
                pass
        return out

    try:
        return await _z._with_client(ws_uri, probe)
    except Exception:
        return {}


async def _wait_for_ready(ws_uri: str, timeout_s: float) -> dict[str, Any]:
    """Poll until both dhu+hud answer whoami, or [timeout_s] elapses.

    Returns {"ready": bool, "surfaces": {surface: whoami_result}} — the
    latest probe snapshot is always included so callers can diagnose *why*
    it isn't ready yet (e.g. the hudEnabled trap) rather than just timing out.
    """
    deadline = time.monotonic() + timeout_s
    surfaces: dict[str, Any] = {}
    while time.monotonic() < deadline:
        surfaces = await _probe_surfaces_once(ws_uri)
        if "dhu" in surfaces and "hud" in surfaces:
            return {"ready": True, "surfaces": surfaces}
        await asyncio.sleep(POLL_INTERVAL_S)
    return {"ready": False, "surfaces": surfaces}


async def _set_dhu_hud_enabled_true(ws_uri: str) -> bool:
    """Call ext.zee.setConfig hudEnabled=true on the dhu isolate. Returns success."""
    async def fn(c: _z.VMClient) -> bool:
        try:
            isos = await c.isolates()
        except Exception:
            return False
        for iso in isos:
            try:
                res = await c.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
            except Exception:
                continue
            if isinstance(res, dict) and res.get("surface") == "dhu":
                await c.rpc("ext.zee.setConfig", {"isolateId": iso["id"], "hudEnabled": "true"})
                return True
        return False

    try:
        return await _z._with_client(ws_uri, fn)
    except Exception:
        return False


def _dump_setup_hud_logcat() -> str:
    """Return recent `setupHud` logcat lines — the native side's own reason
    the HUD engine did/didn't spawn (used in the failure message when `hud`
    never answers while hudEnabled is true)."""
    try:
        r = subprocess.run(
            ["adb", "-s", _z.DEFAULT_SERIAL, "logcat", "-d"],
            capture_output=True, text=True, timeout=20,
        )
        lines = [ln for ln in r.stdout.splitlines() if "setupHud" in ln]
        return "\n".join(lines[-20:]) if lines else "(no setupHud lines found in logcat)"
    except Exception as e:
        return f"(logcat dump failed: {e})"



# ---------------------------------------------------------------------------
# keepalive — mid-slice T2 pulse; restart emu+preflight after N consecutive misses
# ---------------------------------------------------------------------------

def _adb_get_state(serial: str | None = None) -> str | None:
    """Return `adb get-state` text (`device` when healthy), or None on miss."""
    serial = serial or _z.DEFAULT_SERIAL
    try:
        r = subprocess.run(
            ["adb", "-s", serial, "get-state"],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        print(f"[zee_run:keepalive] adb get-state error: {e}", file=sys.stderr)
        return None
    if r.returncode != 0:
        err = (r.stderr or r.stdout or "").strip()
        if err:
            print(f"[zee_run:keepalive] adb get-state rc={r.returncode}: {err}",
                  file=sys.stderr)
        return None
    state = (r.stdout or "").strip()
    return state or None


def _keepalive_misses() -> int:
    try:
        return int(_KEEPALIVE_MISS_FILE.read_text().strip() or "0")
    except (OSError, ValueError):
        return 0


def _set_keepalive_misses(n: int) -> None:
    if n <= 0:
        _KEEPALIVE_MISS_FILE.unlink(missing_ok=True)
        return
    _KEEPALIVE_MISS_FILE.write_text(str(n))


def _emulator_bin() -> Path | None:
    home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not home:
        return None
    cand = Path(home) / "emulator" / "emulator"
    return cand if cand.is_file() else None


def _kill_emulator(serial: str | None = None) -> None:
    """Best-effort stop of the current emulator (adb emu kill + wait)."""
    serial = serial or _z.DEFAULT_SERIAL
    try:
        subprocess.run(
            ["adb", "-s", serial, "emu", "kill"],
            capture_output=True, text=True, timeout=15,
        )
    except (subprocess.TimeoutExpired, OSError):
        pass
    deadline = time.monotonic() + 30.0
    while time.monotonic() < deadline:
        state = _adb_get_state(serial)
        if state is None:
            return
        time.sleep(1.0)


def _restart_emulator(avd: str | None = None) -> bool:
    """Cold-boot the T2 AVD and wait until `adb get-state` returns `device`."""
    avd = avd or DEFAULT_AVD
    emu = _emulator_bin()
    if emu is None:
        print(
            "[zee_run:keepalive] cannot restart emu — set ANDROID_HOME "
            "(expected $ANDROID_HOME/emulator/emulator)",
            file=sys.stderr,
        )
        return False

    print(f"[zee_run:keepalive] stopping emulator (serial={_z.DEFAULT_SERIAL})")
    _kill_emulator()

    # Clear flaky crashpad dirs when present (ENV.md tip).
    try:
        import shutil
        for crashpad in Path("/tmp").glob("android-*"):
            try:
                if crashpad.is_dir():
                    shutil.rmtree(crashpad, ignore_errors=True)
                else:
                    crashpad.unlink(missing_ok=True)
            except OSError:
                pass
    except OSError:
        pass

    cmd = [str(emu), "-avd", avd, "-gpu", "host", "-no-snapshot-load"]
    print(f"[zee_run:keepalive] starting: {' '.join(cmd)}")
    log_path = Path("/tmp/zee_keepalive_emu.log")
    log_fh = log_path.open("w")
    try:
        subprocess.Popen(
            cmd,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    except OSError as e:
        print(f"[zee_run:keepalive] failed to spawn emulator: {e}", file=sys.stderr)
        return False

    try:
        subprocess.run(
            ["adb", "-s", _z.DEFAULT_SERIAL, "wait-for-device"],
            capture_output=True, text=True, timeout=EMU_BOOT_TIMEOUT_S,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        print(f"[zee_run:keepalive] adb wait-for-device failed: {e}", file=sys.stderr)
        return False

    deadline = time.monotonic() + EMU_BOOT_TIMEOUT_S
    while time.monotonic() < deadline:
        state = _adb_get_state()
        if state == "device":
            # Boot completed property — guest may still be animating.
            try:
                boot = subprocess.run(
                    ["adb", "-s", _z.DEFAULT_SERIAL, "shell",
                     "getprop", "sys.boot_completed"],
                    capture_output=True, text=True, timeout=10,
                )
                if (boot.stdout or "").strip() == "1":
                    print("[zee_run:keepalive] emulator back (get-state=device, boot_completed=1)")
                    return True
            except (subprocess.TimeoutExpired, OSError):
                pass
            # device is up even if boot_completed lags — accept shortly
            print("[zee_run:keepalive] emulator get-state=device (waiting boot_completed…)")
        time.sleep(2.0)

    # Final accept if get-state is device even without boot_completed
    if _adb_get_state() == "device":
        print("[zee_run:keepalive] emulator get-state=device (boot_completed not confirmed)")
        return True
    print("[zee_run:keepalive] emulator restart timed out", file=sys.stderr)
    return False


def cmd_keepalive(
    tier: str,
    max_misses: int = KEEPALIVE_MAX_MISSES,
    do_restart: bool = True,
) -> int:
    """One mid-slice pulse. After `max_misses` consecutive misses → emu+preflight.

    Returns 0 when healthy (or after a successful recover). Returns 1 on a
    counted miss below the threshold, or when restart/preflight fails.
    """
    import json

    result: dict[str, Any] = {
        "tier": tier,
        "cmd": "keepalive",
        "serial": _z.DEFAULT_SERIAL,
        "maxMisses": max_misses,
    }

    if tier != "t2":
        result["pass"] = True
        result["note"] = "keepalive is T2-only — nothing to pulse"
        print(json.dumps(result, indent=2))
        return 0

    state = _adb_get_state()
    result["getState"] = state
    healthy = state == "device"
    result["healthy"] = healthy

    if healthy:
        prev = _keepalive_misses()
        _set_keepalive_misses(0)
        result["consecutiveMisses"] = 0
        result["clearedMisses"] = prev
        result["pass"] = True
        result["action"] = "ok"
        print(f"[zee_run:keepalive] ok — adb get-state={state!r} (misses cleared)")
        print(json.dumps(result, indent=2))
        return 0

    misses = _keepalive_misses() + 1
    _set_keepalive_misses(misses)
    result["consecutiveMisses"] = misses
    result["pass"] = False
    print(
        f"[zee_run:keepalive] MISS {misses}/{max_misses} — "
        f"adb get-state={state!r} (want 'device')",
        file=sys.stderr,
    )

    if misses < max_misses:
        result["action"] = "count"
        result["remedy"] = (
            f"adb device {_z.DEFAULT_SERIAL!r} not ready — pulse again; "
            f"after {max_misses} consecutive misses keepalive restarts "
            "emu + preflight"
        )
        print(json.dumps(result, indent=2))
        return 1

    if not do_restart:
        result["action"] = "threshold-no-restart"
        result["remedy"] = (
            "max misses reached; re-run without --no-restart to cold-boot "
            "the AVD + preflight, then `up --tier t2`"
        )
        print(json.dumps(result, indent=2))
        return 1

    print(
        f"[zee_run:keepalive] {misses} consecutive misses — "
        "restarting emu + preflight",
        file=sys.stderr,
    )
    # Drop any wedged host-side flutter run before the AVD comes back.
    cmd_down(tier)

    restarted = _restart_emulator()
    result["emuRestarted"] = restarted
    if not restarted:
        result["action"] = "restart-failed"
        result["remedy"] = (
            f"manual: $ANDROID_HOME/emulator/emulator -avd {DEFAULT_AVD} "
            "-gpu host -no-snapshot-load && adb wait-for-device && "
            "uv run dev/zee_run.py preflight --tier t2 --fix && "
            "uv run dev/zee_run.py up --tier t2"
        )
        print(json.dumps(result, indent=2))
        return 1

    ok, pf = cmd_preflight(tier, fix=True)
    result["preflight"] = pf
    result["preflightOk"] = ok
    if ok:
        _set_keepalive_misses(0)
        result["consecutiveMisses"] = 0
        result["pass"] = True
        result["action"] = "recovered"
        result["remedy"] = (
            "emu + preflight recovered — re-run "
            "`uv run dev/zee_run.py up --tier t2` before driving"
        )
        print("[zee_run:keepalive] recovered — re-run `up --tier t2`")
        print(json.dumps(result, indent=2))
        return 0

    result["action"] = "preflight-failed"
    result["remedy"] = pf.get("remedy") or "preflight failed after emu restart"
    print(json.dumps(result, indent=2))
    return 1


# ---------------------------------------------------------------------------
# up
# ---------------------------------------------------------------------------

def cmd_up(tier: str, self_heal: bool = True) -> int:
    log_path, pid_path = _tier_files(tier)
    uri_path = _vm_uri_file(tier)

    # --- T2: preflight FIRST — the overlay display must exist before
    # flutter run starts, else the HUD engine never spawns and `up` times
    # out at 60s with no useful message (FIX 1). --fix is implied here so
    # the launch is deterministic; standalone `preflight` still defaults to
    # no --fix so it can be used as a pure health check.
    if tier == "t2":
        ok, pf = cmd_preflight(tier, fix=True)
        if not ok:
            print(f"[zee_run] preflight FAILED: {pf.get('remedy', pf)}", file=sys.stderr)
            return 1
        print(f"[zee_run] preflight OK (hudEnabled={pf.get('hudEnabled')!r})")

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
        # T1 is pure-Dart fakes on desktop. Linux historically; macOS once
        # macos/ + desktop_multi_window MainFlutterWindow wiring exist.
        import platform as _platform
        t1_device = "macos" if _platform.system() == "Darwin" else "linux"
        cmd = ["flutter", "run", "-d", t1_device]
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
    uri_path.write_text(ws_uri)
    print(f"[zee_run] URI persisted → {uri_path}")

    # --- wait for both dhu + hud surfaces to answer whoami --------------------
    # Two-phase wait (FIX 2): a first SELF_HEAL_CHECK_S checkpoint to diagnose
    # the hudEnabled=false trap (setupHud's native gate silently skips the HUD
    # engine — no amount of extra waiting will ever make `hud` answer), then
    # the remainder of the budget for the ordinary slow-cold-build case.
    print("[zee_run] waiting for both dhu + hud surfaces …")
    first = asyncio.run(_wait_for_ready(ws_uri, timeout_s=min(SELF_HEAL_CHECK_S, SURFACE_TIMEOUT_S)))

    if not first["ready"]:
        surfaces = first["surfaces"]
        only_dhu = "dhu" in surfaces and "hud" not in surfaces
        dhu_hud_enabled = (surfaces.get("dhu") or {}).get("hudEnabled")

        if tier == "t2" and self_heal and only_dhu and dhu_hud_enabled is False:
            print(
                "[zee_run] self-heal: only dhu answered and hudEnabled=false — "
                "this is an unrecoverable trap (setupHud's native gate skips the "
                "HUD engine entirely); setting hudEnabled=true and restarting once"
            )
            healed = asyncio.run(_set_dhu_hud_enabled_true(ws_uri))
            print(f"[zee_run] self-heal: ext.zee.setConfig hudEnabled=true → {healed}")
            cmd_down(tier)
            print("[zee_run] self-heal: restarting (self-heal disabled on this retry)")
            return cmd_up(tier, self_heal=False)

        remaining = max(0.0, SURFACE_TIMEOUT_S - SELF_HEAL_CHECK_S)
        second = asyncio.run(_wait_for_ready(ws_uri, timeout_s=remaining)) if remaining > 0 else first
        ready = second["ready"]
        surfaces = second["surfaces"]
    else:
        ready = True
        surfaces = first["surfaces"]

    if not ready:
        msg = f"[zee_run] timed out waiting for both surfaces; found: {list(surfaces)}"
        if tier == "t2" and "hud" not in surfaces:
            msg += "\n[zee_run] setupHud logcat (native-side reason):\n" + _dump_setup_hud_logcat()
        print(msg, file=sys.stderr)
        return 1

    print(f"[zee_run] READY — both surfaces up")
    print(f"[zee_run] VM URI: {ws_uri}")
    print(f"\nExport for other tools (optional — driving tools read {uri_path} automatically):")
    print(f"  export ZEE_VM_URI='{ws_uri}'")
    return 0


# ---------------------------------------------------------------------------
# down
# ---------------------------------------------------------------------------

def cmd_down(tier: str) -> int:
    _, pid_path = _tier_files(tier)
    uri_path = _vm_uri_file(tier)
    if not pid_path.exists():
        print(f"[zee_run] no PID file for tier {tier} — nothing to stop")
        # Even with no local pid file, a previous session may have left the
        # app running on-device (FIX 3) — clean it up on T2 regardless.
        if tier == "t2":
            _adb("shell", "am", "force-stop", "com.zeepowertoys.zee_power_toys")
            print("[zee_run] force-stopped com.zeepowertoys.zee_power_toys on device")
        uri_path.unlink(missing_ok=True)
        return 0
    try:
        pid = int(pid_path.read_text().strip())
        # Kill the entire process group so dart/gradle children don't orphan
        # (up launched flutter run with start_new_session=True).
        try:
            pgid = os.getpgid(pid)
            os.killpg(pgid, signal.SIGTERM)
            print(f"[zee_run] sent SIGTERM to pgid={pgid} (pid={pid})")
        except (ProcessLookupError, PermissionError):
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
                # PermissionError here (observed live, self-heal down/up cycle):
                # by the time we escalate, the pgid can already be gone/reaped
                # or reassigned to something we no longer have rights to signal
                # — either way there is nothing left of OUR process to kill, so
                # this must not raise (an unhandled exception here would abort
                # the self-heal restart in cmd_up, which calls cmd_down mid-flow).
                try:
                    os.killpg(pgid, signal.SIGKILL)
                    print(f"[zee_run] escalated to SIGKILL for pgid={pgid}")
                except (ProcessLookupError, PermissionError):
                    print(f"[zee_run] escalate to SIGKILL for pgid={pgid} skipped (already gone)")
    except (ValueError, ProcessLookupError):
        print(f"[zee_run] process already gone")
    pid_path.unlink(missing_ok=True)
    # Remove this tier's session URI file so stale URIs never shadow a future session.
    uri_path.unlink(missing_ok=True)
    if tier == "t2":
        _clear_stale_forwards()
        # FIX 3: the pgid kill above only stops the HOST-side `flutter run`
        # process group — it does not stop the app running ON the device.
        # Safe here (only here): `flutter run` is already dead, so this is
        # not the "force-stop a live flutter run" hazard from the skill doc.
        _adb("shell", "am", "force-stop", "com.zeepowertoys.zee_power_toys")
        print("[zee_run] force-stopped com.zeepowertoys.zee_power_toys on device")
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

    pf_p = sub.add_parser("preflight", help="T2 device-readiness checks (auto-run by `up --tier t2`)")
    pf_p.add_argument("--tier", choices=["t1", "t2"], default="t2",
                      help="target tier (default: t2)")
    pf_p.add_argument("--fix", action="store_true",
                      help="repair a wrong/missing overlay_display_devices setting")

    up_p = sub.add_parser("up", help="start flutter run and wait for both surfaces")
    up_p.add_argument("--tier", choices=["t1", "t2"], default="t1",
                      help="target tier (default: t1)")
    up_p.add_argument("--no-self-heal", action="store_true",
                      help="disable the hudEnabled=false auto-recovery (T2 only)")

    dn_p = sub.add_parser("down", help="stop the running flutter run for a tier")
    dn_p.add_argument("--tier", choices=["t1", "t2"], default="t1",
                      help="target tier (default: t1)")

    ka_p = sub.add_parser(
        "keepalive",
        help="mid-slice T2 adb get-state pulse; restart emu+preflight after N misses",
    )
    ka_p.add_argument("--tier", choices=["t1", "t2"], default="t2",
                      help="target tier (default: t2; keepalive is a no-op on t1)")
    ka_p.add_argument(
        "--max-misses", type=int, default=KEEPALIVE_MAX_MISSES,
        help=f"consecutive get-state misses before emu restart (default: {KEEPALIVE_MAX_MISSES})",
    )
    ka_p.add_argument(
        "--no-restart", action="store_true",
        help="only count misses — do not cold-boot the AVD at threshold",
    )

    args = p.parse_args(argv)
    if args.cmd == "preflight":
        ok, result = cmd_preflight(args.tier, fix=args.fix)
        import json
        print(json.dumps(result, indent=2))
        return 0 if ok else 1
    elif args.cmd == "up":
        return cmd_up(args.tier, self_heal=not args.no_self_heal)
    elif args.cmd == "down":
        return cmd_down(args.tier)
    elif args.cmd == "keepalive":
        return cmd_keepalive(
            args.tier,
            max_misses=max(1, args.max_misses),
            do_restart=not args.no_restart,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

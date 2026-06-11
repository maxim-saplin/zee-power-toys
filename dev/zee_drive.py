#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""zee_drive.py — minimal Feedback Loop client for zee-power-toys (ADR 0004).

Seed of the project's real VM-service channel. It talks to ONE Dart VM service
and reaches EVERY Dart isolate of the two-engine multidisplay PoC (the primary
"DHU" isolate + the secondary "HUD" isolate spawned by FlutterEngineGroup),
calling the `ext.zee.*` extensions registered in `lib/debug/agent_extensions.dart`.

Discovery (in precedence order):
  1. explicit --vm-uri / $ZEE_VM_URI override
  2. canonical session file /tmp/zee_vm_uri.txt (written by zee_run.py up)
  3. flutter-run log file ($ZEE_RUN_LOG, default /tmp/zee_run_t1.log)
  4. adb logcat scan + adb forward  [Android only]

Subcommands:
  isolates                 list every isolate (id, name, number, ext.zee.* RPCs)
  whoami-all               call ext.zee.whoami on EVERY isolate; print a table
  call <ext> [--isolate primary|hud|<id>|<name>] [k=v ...]
                           call an arbitrary ext.zee.* on a chosen isolate
                           (default isolate: the first root isolate)

Examples:
  ./zee_drive.py isolates
  ./zee_drive.py whoami-all
  ./zee_drive.py call ext.zee.whoami --isolate hud
  ./zee_drive.py call ext.zee.bump   --isolate hud
  ZEE_VM_URI=ws://127.0.0.1:8181/TOKEN=/ws ./zee_drive.py whoami-all
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import subprocess
import sys
from typing import Any

import websockets

# --------------------------------------------------------------------------- #
# Config (overridable via environment)
# --------------------------------------------------------------------------- #
DEFAULT_SERIAL = os.environ.get("ADB_SERIAL", "emulator-5554")
LOCAL_FORWARD_PORT = int(os.environ.get("ZEE_LOCAL_PORT", "8181"))
RPC_TIMEOUT_S = float(os.environ.get("ZEE_RPC_TIMEOUT", "30"))
# Default log path for `flutter run -d linux` output (T1 desktop).
# Set $ZEE_RUN_LOG to override (useful for parallel sessions).
DEFAULT_RUN_LOG = os.environ.get("ZEE_RUN_LOG", "/tmp/zee_run_t1.log")
# Canonical current-session URI written by `zee_run.py up` (any tier).
# Precedence: explicit override > this file > run-log scan > logcat scan.
_VM_URI_FILE = "/tmp/zee_vm_uri.txt"

# Lines Flutter/Dart emit when the VM service starts. Cover modern + legacy.
VM_PATTERNS = [
    re.compile(r"Dart VM [Ss]ervice.*?listening on (http://[^\s/]+/[A-Za-z0-9_=\-]+/?)"),
    re.compile(r"A Dart VM Service .*?:\s+(http://[^\s/]+/[A-Za-z0-9_=\-]+/?)"),
    re.compile(r"Observatory.*?listening on (http://[^\s/]+/[A-Za-z0-9_=\-]+/?)"),
]


# --------------------------------------------------------------------------- #
# adb + VM-service discovery
# --------------------------------------------------------------------------- #
def adb(*args: str, serial: str = DEFAULT_SERIAL, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["adb", "-s", serial, *args],
        check=check, capture_output=True, text=True, timeout=30,
    )


def _normalize_ws_uri(uri: str) -> str:
    """Accept an http(s)/ws(s) VM URI and normalize to a `…/ws` WebSocket URI."""
    raw = uri.strip()
    if not raw:
        raise RuntimeError("empty VM service URI")
    if raw.startswith("http://"):
        raw = "ws://" + raw[len("http://"):]
    elif raw.startswith("https://"):
        raw = "wss://" + raw[len("https://"):]
    if not raw.startswith(("ws://", "wss://")):
        raise RuntimeError(f"unsupported VM service URI: {uri!r}")
    return raw if raw.rstrip("/").endswith("/ws") else raw.rstrip("/") + "/ws"


def _scan_logcat_for_vm_uri(serial: str, max_lines: int = 6000) -> str | None:
    """Return the most recent VM service http URI seen in logcat, or None."""
    proc = adb("logcat", "-d", "-v", "brief", "-t", str(max_lines), serial=serial, check=False)
    found = None
    for line in proc.stdout.splitlines():
        for pat in VM_PATTERNS:
            m = pat.search(line)
            if m:
                found = m.group(1)
    return found


def _scan_flutter_run_log_for_vm_uri(log_path: str = DEFAULT_RUN_LOG) -> str | None:
    """Return the most recent VM service http URI from a flutter-run log file, or None.

    flutter run -d linux writes its stdout to the file at [log_path] (or
    $ZEE_RUN_LOG).  This is the only reliable URI source on T1 desktop — there
    is no logcat on Linux.  The same patterns work for Android flutter run logs.
    """
    try:
        with open(log_path, "r", errors="replace") as fh:
            found = None
            for line in fh:
                for pat in VM_PATTERNS:
                    m = pat.search(line)
                    if m:
                        found = m.group(1)
            return found
    except OSError:
        return None


def _parse_vm_uri(uri: str) -> tuple[int, str]:
    """Return (remote_port, auth_token) from a Dart VM service http URI."""
    m = re.match(r"https?://[^:]+:(\d+)/([^/]*)/?", uri)
    if not m:
        raise RuntimeError(f"cannot parse VM service URI: {uri!r}")
    return int(m.group(1)), m.group(2)


def _forward_port(remote_port: int, serial: str, local_port: int = LOCAL_FORWARD_PORT) -> int:
    adb("forward", f"tcp:{local_port}", f"tcp:{remote_port}", serial=serial)
    return local_port


def resolve_ws_uri(serial: str = DEFAULT_SERIAL, override: str | None = None,
                   run_log: str = DEFAULT_RUN_LOG) -> str:
    """Discover (or accept an override of) the host-reachable WebSocket URI.

    Precedence:
      1. explicit override (arg or $ZEE_VM_URI)
      2. canonical session file /tmp/zee_vm_uri.txt  (written by `zee_run.py up`,
         deleted by `zee_run.py down`; always reflects the most-recently-started
         session regardless of tier — fixes T1/T2 cross-contamination)
      3. flutter-run log file ($ZEE_RUN_LOG, default /tmp/zee_run_t1.log)
         — legacy fallback for sessions started without zee_run.py
      4. adb logcat scan + adb forward  [Android/T2/T3 fallback]
    """
    override = override or os.environ.get("ZEE_VM_URI")
    if override:
        return _normalize_ws_uri(override)

    # Canonical session file — written by `zee_run.py up` for both tiers.
    # This is the authoritative source when the session was started via zee_run.py.
    try:
        with open(_VM_URI_FILE, "r") as fh:
            uri = fh.read().strip()
        if uri:
            return _normalize_ws_uri(uri)
    except OSError:
        pass

    # Legacy fallback: flutter-run log (T1 desktop + flutter-run Android sessions
    # started outside zee_run.py).
    uri = _scan_flutter_run_log_for_vm_uri(run_log)
    if uri:
        # T1 desktop: the VM service is host-local; no adb forward needed.
        # T2 with flutter run: flutter run already set up the forward — use as-is.
        return _normalize_ws_uri(uri)

    # Fallback: logcat scan for adb-started builds (T2/T3, am start workflow).
    uri = _scan_logcat_for_vm_uri(serial)
    if not uri:
        raise RuntimeError(
            "could not find a 'Dart VM Service is listening on …' line in "
            f"session file ({_VM_URI_FILE}), run log ({run_log}), or logcat. "
            "Is a DEBUG build running? "
            "Run `dev/zee_run.py up` to launch, or set $ZEE_VM_URI.")
    remote_port, token = _parse_vm_uri(uri)
    local_port = _forward_port(remote_port, serial=serial)
    return _normalize_ws_uri(f"ws://127.0.0.1:{local_port}/{token}/")


# --------------------------------------------------------------------------- #
# JSON-RPC over a single WebSocket connection
# --------------------------------------------------------------------------- #
class VMClient:
    """Thin JSON-RPC client over one VM-service WebSocket connection."""

    def __init__(self, ws: Any) -> None:
        self._ws = ws
        self._id = 0

    async def rpc(self, method: str, params: dict[str, Any] | None = None) -> Any:
        self._id += 1
        req_id = self._id
        await self._ws.send(json.dumps(
            {"jsonrpc": "2.0", "id": req_id, "method": method, "params": params or {}}))
        while True:
            raw = await asyncio.wait_for(self._ws.recv(), timeout=RPC_TIMEOUT_S)
            msg = json.loads(raw)
            if msg.get("id") == req_id:               # ignore unrelated stream events
                if "error" in msg:
                    raise RuntimeError(json.dumps(msg["error"]))
                return msg.get("result")

    async def isolates(self) -> list[dict[str, Any]]:
        vm = await self.rpc("getVM")
        return vm.get("isolates", [])

    async def resolve_isolate(self, selector: str | None) -> str:
        """Map a selector to an isolateId.

        selector may be: None (first root isolate), a full isolateId, an
        isolate name/number, or a logical surface (`primary`/`hud`) — the
        latter resolved by calling ext.zee.whoami on each isolate and matching
        the returned `surface`.
        """
        isos = await self.isolates()
        if not isos:
            raise RuntimeError("VM reports no isolates yet — is the app fully started?")
        if selector is None:
            return isos[0]["id"]
        ids = {i["id"] for i in isos}
        if selector in ids:
            return selector
        for iso in isos:                              # name / number match
            if selector == iso.get("name") or selector == str(iso.get("number")):
                return iso["id"]
        if selector in ("primary", "dhu", "hud"):      # surface match via whoami
            for iso in isos:
                try:
                    res = await self.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
                except Exception:
                    continue
                surface = res.get("surface") if isinstance(res, dict) else None
                # 'dhu' selector matches both 'dhu' and legacy 'primary' labels.
                if surface == selector or (selector == "dhu" and surface == "primary"):
                    return iso["id"]
            raise RuntimeError(
                f"no isolate reports surface={selector!r}. "
                f"Is the {selector} engine running and its ext.zee.* registered?")
        have = [(i["id"], i.get("name")) for i in isos]
        raise RuntimeError(f"cannot resolve isolate {selector!r}; have {have}")


async def _with_client(ws_uri: str, fn):
    async with websockets.connect(ws_uri, max_size=8 * 1024 * 1024) as ws:
        return await fn(VMClient(ws))


# --------------------------------------------------------------------------- #
# Subcommands
# --------------------------------------------------------------------------- #
async def _cmd_isolates(c: VMClient) -> dict[str, Any]:
    isos = await c.isolates()
    out = []
    for iso in isos:
        full = await c.rpc("getIsolate", {"isolateId": iso["id"]})
        rpcs = [r for r in (full.get("extensionRPCs") or []) if isinstance(r, str)]
        out.append({
            "id": iso["id"],
            "name": iso.get("name"),
            "number": iso.get("number"),
            "rootLib": (full.get("rootLib") or {}).get("uri"),
            "zeeExtensions": sorted(r for r in rpcs if r.startswith("ext.zee.")),
            "extensionRPCs": sorted(rpcs),
        })
    return {"count": len(out), "isolates": out}


async def _cmd_whoami_all(c: VMClient) -> list[dict[str, Any]]:
    isos = await c.isolates()
    rows = []
    for iso in isos:
        row: dict[str, Any] = {"isolateId": iso["id"], "name": iso.get("name")}
        try:
            row["whoami"] = await c.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
        except Exception as e:                        # extension missing in this isolate
            row["whoami"] = {"error": str(e)}
        rows.append(row)
    return rows


async def _cmd_call(c: VMClient, ext: str, isolate: str | None, kvs: list[str]) -> Any:
    iso_id = await c.resolve_isolate(isolate)
    params: dict[str, Any] = {"isolateId": iso_id}
    for kv in kvs:
        if "=" not in kv:
            raise RuntimeError(f"bad param {kv!r} (expected k=v)")
        k, v = kv.split("=", 1)
        params[k] = v
    return await c.rpc(ext, params)


def _print_whoami_table(rows: list[dict[str, Any]]) -> None:
    hdr = f"{'ISOLATE ID':<34} {'NAME':<10} {'SURFACE':<8} {'ISOLATE(hash)':<14} {'TICK':>5}"
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        w = r.get("whoami") or {}
        if isinstance(w, dict) and "error" not in w:
            print(f"{r['isolateId']:<34} {str(r.get('name')):<10} "
                  f"{str(w.get('surface')):<8} {str(w.get('isolate')):<14} {str(w.get('tick')):>5}")
        else:
            print(f"{r['isolateId']:<34} {str(r.get('name')):<10} "
                  f"{'<none>':<8} {'-':<14} {'-':>5}   ({w.get('error', w)})")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Minimal zee-power-toys Feedback Loop client.")
    p.add_argument("--serial", default=DEFAULT_SERIAL, help="adb serial (default: %(default)s)")
    p.add_argument("--vm-uri", default=None, help="override VM service URI (else $ZEE_VM_URI / logcat)")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("isolates", help="list every isolate + its ext.zee.* RPCs")
    sub.add_parser("whoami-all", help="call ext.zee.whoami on every isolate, print a table")
    sp_call = sub.add_parser("call", help="call an arbitrary ext.zee.* on a chosen isolate")
    sp_call.add_argument("ext", help="fully-qualified extension, e.g. ext.zee.whoami")
    sp_call.add_argument("--isolate", default=None, help="primary|hud|<isolateId>|<name> (default: first)")
    sp_call.add_argument("kvs", nargs="*", help="extra params as k=v")

    args = p.parse_args(argv)

    try:
        ws_uri = resolve_ws_uri(serial=args.serial, override=args.vm_uri)
    except Exception as e:
        print(json.dumps({"error": f"VM discovery failed: {e}"}, indent=2), file=sys.stderr)
        return 3

    try:
        if args.cmd == "isolates":
            res = asyncio.run(_with_client(ws_uri, _cmd_isolates))
            print(json.dumps(res, indent=2))
        elif args.cmd == "whoami-all":
            rows = asyncio.run(_with_client(ws_uri, _cmd_whoami_all))
            _print_whoami_table(rows)
            print()
            print(json.dumps(rows, indent=2))
        elif args.cmd == "call":
            res = asyncio.run(_with_client(
                ws_uri, lambda c: _cmd_call(c, args.ext, args.isolate, args.kvs)))
            print(json.dumps(res, indent=2))
        else:  # pragma: no cover
            p.error(f"unknown command {args.cmd!r}")
    except Exception as e:
        print(json.dumps({"error": str(e), "ws_uri": ws_uri}, indent=2), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

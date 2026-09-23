#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""feedback_loop.py — tier-agnostic Feedback Loop client (ADR 0004, Block 0002).

One class (`FeedbackLoop`) fronts semantic ops and routes each to the right
channel per tier.  T1 (Linux desktop) uses the VM-service channel for
everything including `inject` (Block 0003: VM-service routes to ext.zee.inject
which calls FakeCarSignals on the DHU isolate; the DHU relay propagates to HUD).
The native channel is a clean stub that refuses with an explicit error — no fake
success.  T2/T3 slot in by providing a real `NativeChannel` implementation;
call sites do not change.

VM-service channel: reuses `zee_drive.VMClient` + `resolve_ws_uri`.
Native channel:     `T1NativeStub` — raises on any call.

Surface resolution (ADR 0004 §21):
  Both isolates are named `main`.  Surfaces are resolved by calling
  `ext.zee.whoami` on each isolate and matching the `surface` field.
  `FeedbackLoop.connect()` polls `getVM` until both `dhu` and `hud`
  surfaces answer before returning.

CLI subcommands (output is always JSON to stdout):
  whoami-all
  dump-state      --surface dhu|hud
  read-view-model --surface dhu|hud
  set-config      --surface dhu|hud  key=value ...
  tap             --surface dhu|hud  --key <ValueKey>
  shot            --surface dhu|hud  [--out path/to/file.png]
                  [--layer flutter|native|both] [--expect WxH]
                  flutter (default): RepaintBoundary only — CANNOT see the
                    native minimap composite (docs/issues/0009-minimap-under-
                    layer.md:39). native: full device composite via `adb
                    exec-out screencap` (no VM session needed). both: writes
                    both, reports both dimension pairs.
  hud-display                          discover the HUD secondary display
                                        (displayId/w/h/dpi) via dumpsys display
  inject          kind=speed|blinker|charge|battery  value=...  [--surface dhu]
  speedcam-demo   on|off [--no-overlay]   # 0089 Demo(+Overlay) one-shot
  speedcam-fixture --source ynavi --cam-type SPEED --lat .. --lon ..

Examples:
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py whoami-all
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py tap --surface dhu --key blinker-shape-arrows
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py inject kind=speed value=80
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py inject kind=blinker value=left
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py inject kind=charge charging=true kw=50
  uv run dev/feedback_loop.py hud-display
  uv run dev/feedback_loop.py speedcam-demo on
  uv run dev/feedback_loop.py speedcam-demo off
  uv run dev/feedback_loop.py speedcam-fixture --source ynavi --cam-type SPEED \
      --lat 53.907996 --lon 27.424118 --event-id a2 --approach-m 200
  uv run dev/feedback_loop.py shot --surface hud --layer both --out /tmp/hud.png
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
import re
import struct
import subprocess
import sys
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Import the low-level VM layer from zee_drive (same directory).
# ---------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(__file__))
import zee_drive as _z  # VMClient, resolve_ws_uri, _with_client


# ---------------------------------------------------------------------------
# Native channel abstraction
# ---------------------------------------------------------------------------

class NativeChannel(ABC):
    """Abstract native-side channel (T2: ADB broadcast; T3: real AdaptAPI)."""

    @abstractmethod
    async def inject(self, kv: dict[str, str]) -> dict[str, Any]:
        """Inject key-value config via the native stack.

        On T2/T3 this broadcasts to the native service; on T1 it raises.
        """


class T1NativeStub(NativeChannel):
    """T1 stub: native channel is NOT available on desktop.

    Descends the stack and gains teeth on T2/T3 — see ADR 0004.
    Raises unconditionally so callers get a clear failure rather than silent
    fake success.
    """

    async def inject(self, kv: dict[str, str]) -> dict[str, Any]:
        raise NotImplementedError(
            "native channel not available on T1 — "
            "descends the stack on T2/T3 (see ADR 0004).  "
            "Use inject over the VM-service channel for T1 signal injection."
        )


class T2NativeChannel(NativeChannel):
    """T2 native channel: ADB broadcast → com.zeepowertoys.SIMULATE.

    inject(kv) maps the feedback-loop kv dict to the native broadcast extras:
      kind=speed value=80          → --es kind speed --es value 80
      kind=blinker value=left      → --es kind blinker --es value left
      kind=charge value=true:400:20:8  → --es kind charge --es value true:400:20:8
      kind=battery value=80:27.5   → --es kind battery --es value 80:27.5
      kind=powerFlow value=drive   → --es kind powerFlow --es value drive

    The "value" extra for charge must be pre-formatted as "<bool>:<volts>:<amps>:<kw>"
    by the caller (e.g. value=true:400.0:20.5:8.2).

    IMPORTANT: use -n <component> in the adb am broadcast command so the
    broadcast reaches the receiver even when the app is in background
    (Android 8+ blocks implicit broadcasts in background without the component flag).

    dump() sends a DUMP broadcast and parses the result from the adb output.
    The DUMP broadcast uses setResultData(json) — the result data appears as:
      "Broadcast completed: result=0, data=<json>"
    """

    def __init__(self, serial: str = _z.DEFAULT_SERIAL) -> None:
        self._serial = serial

    def _adb(self, *args: str) -> subprocess.CompletedProcess:
        return _z.adb(*args, serial=self._serial)

    async def inject(self, kv: dict[str, str]) -> dict[str, Any]:
        kind  = kv.get("kind", "")
        value = kv.get("value", "")
        if not kind:
            raise ValueError("inject kv must contain 'kind'")
        # -n specifies the explicit component so the broadcast is delivered even
        # when the app is in the background (Android 8+ background broadcast restriction).
        proc = self._adb("shell", "am", "broadcast",
                         "-n", "com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver",
                         "-a", "com.zeepowertoys.SIMULATE",
                         "--es", "kind", kind,
                         "--es", "value", value)
        return {"adb_stdout": proc.stdout.strip(), "kind": kind, "value": value}

    async def dump(self) -> dict[str, Any]:
        """Send DUMP broadcast and parse the native snapshot JSON from result data."""
        # -n specifies the explicit component (same background restriction workaround).
        proc = self._adb("shell", "am", "broadcast",
                         "-n", "com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver",
                         "-a", "com.zeepowertoys.DUMP")
        output = proc.stdout.strip()
        # The adb am broadcast output for a receiver that called setResultData() contains:
        #   Broadcast completed: result=0, data="<json>"
        # Parse the data= field.
        m = re.search(r'data="(.+?)"(?:\s|$)', output)
        if m:
            try:
                return json.loads(m.group(1))
            except json.JSONDecodeError:
                return {"raw": m.group(1)}
        # Also try without quotes (some Android versions omit them)
        m2 = re.search(r'data=(\{.+\})', output)
        if m2:
            try:
                return json.loads(m2.group(1))
            except json.JSONDecodeError:
                pass
        return {"raw_output": output, "error": "could not parse JSON from DUMP result"}


# ---------------------------------------------------------------------------
# Native composite capture — `adb exec-out screencap` (Block 0027).
#
# ext.zee.shot (the VM-service path) captures ONLY the Flutter RepaintBoundary.
# On the HUD surface that misses the native MinimapView TextureView entirely —
# the map is composited by Android, under the transparent Flutter overlay, and
# is structurally invisible to the Flutter-side capture (docs/issues/0009-
# minimap-under-layer.md:39). `adb exec-out screencap -p -d <displayId>`
# captures the full device composite instead — this is the only way to
# verify the thing the product actually is.
# ---------------------------------------------------------------------------

_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def _parse_wxh(s: str) -> tuple[int, int]:
    """Parse a 'WxH' string (e.g. '1024x576') into (w, h)."""
    m = re.match(r"^\s*(\d+)\s*x\s*(\d+)\s*$", s)
    if not m:
        raise ValueError(f"bad --expect value {s!r}; expected WxH e.g. 1024x576")
    return int(m.group(1)), int(m.group(2))


def shot_native(
    surface: str,
    out_path: str | None,
    *,
    serial: str = _z.DEFAULT_SERIAL,
    expect: tuple[int, int] | None = None,
) -> dict[str, Any]:
    """Capture the full native composite via `adb exec-out screencap -p -d <displayId>`.

    surface == 'hud': displayId is discovered via `resolve_hud_display()` — the
      real secondary display the HUD Presentation lives on (do NOT hardcode).
    surface == 'dhu' (or anything else): displayId 0 (the primary display).

    The PNG's IHDR chunk (bytes 16..24: width, height, both big-endian uint32)
    is parsed directly — no Pillow dependency. When [expect] (w, h) is given
    and the capture does not match, nothing is written to [out_path] and the
    returned dict carries an "error" key; callers should treat that as a
    hard failure (non-zero exit at the CLI).
    """
    display_id = 0
    if surface == "hud":
        info = _z.resolve_hud_display(serial=serial)
        display_id = info["displayId"]

    proc = _z.adb(
        "exec-out", "screencap", "-p", "-d", str(display_id),
        serial=serial, binary=True, check=True,
    )
    png: bytes = proc.stdout

    if len(png) < 24 or png[:8] != _PNG_MAGIC:
        return {
            "error": "screencap did not return a valid PNG",
            "displayId": display_id,
            "bytes": len(png),
        }

    w, h = struct.unpack(">II", png[16:24])

    if expect is not None and (w, h) != tuple(expect):
        return {
            "error": "dimension mismatch",
            "got": [w, h],
            "want": list(expect),
            "displayId": display_id,
        }

    result: dict[str, Any] = {"surface": surface, "displayId": display_id, "w": w, "h": h}
    if out_path:
        p = Path(out_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(png)
        result["saved_to"] = str(p)
    return result


# ---------------------------------------------------------------------------
# FeedbackLoop — the tier-agnostic semantic-ops layer
# ---------------------------------------------------------------------------

class FeedbackLoop:
    """Tier-agnostic Feedback Loop client (ADR 0004).

    Instantiate with `await FeedbackLoop.connect(ws_uri)`.

    All VM-service ops resolve the target isolate from the `surface` arg
    via `ext.zee.whoami` (ADR 0004: both isolates are named `main`).
    """

    def __init__(
        self,
        client: _z.VMClient,
        surface_map: dict[str, str],   # surface -> isolateId
        native: NativeChannel,
    ) -> None:
        self._c = client
        self._surfaces = surface_map   # populated by connect()
        self._native = native

    # ------------------------------------------------------------------
    # Factory — use _open_feedback_loop() below; this is kept as a
    # docstring anchor for readers of this class.
    # ------------------------------------------------------------------
    # Instantiate via: asyncio.run(_open_feedback_loop(ws_uri, native, fn))
    # connect() is intentionally not a classmethod here because the
    # WebSocket connection must stay alive for the full session; the
    # _open_feedback_loop context manager owns its lifetime.

    # ------------------------------------------------------------------
    # VM-service ops
    # ------------------------------------------------------------------

    async def whoami_all(self) -> list[dict[str, Any]]:
        """Call ext.zee.whoami on every isolate; return raw rows."""
        isos = await self._c.isolates()
        rows = []
        for iso in isos:
            row: dict[str, Any] = {"isolateId": iso["id"], "name": iso.get("name")}
            try:
                row["whoami"] = await self._c.rpc(
                    "ext.zee.whoami", {"isolateId": iso["id"]}
                )
            except Exception as e:
                row["whoami"] = {"error": str(e)}
            rows.append(row)
        return rows

    async def dump_state(self, surface: str) -> dict[str, Any]:
        """Return raw state dump for [surface] via ext.zee.dumpState."""
        iso_id = await self._resolve(surface)
        return await self._c.rpc("ext.zee.dumpState", {"isolateId": iso_id})

    async def read_view_model(self, surface: str) -> dict[str, Any]:
        """Return derived view-model for [surface] via ext.zee.readViewModel."""
        iso_id = await self._resolve(surface)
        return await self._c.rpc("ext.zee.readViewModel", {"isolateId": iso_id})

    async def set_config(self, surface: str, **kv: str) -> dict[str, Any]:
        """Write config key-values for [surface] via ext.zee.setConfig."""
        iso_id = await self._resolve(surface)
        params: dict[str, Any] = {"isolateId": iso_id}
        params.update(kv)
        return await self._c.rpc("ext.zee.setConfig", params)

    async def tap(self, surface: str, key: str) -> dict[str, Any]:
        """Dispatch a synthetic tap to the widget with ValueKey([key]) on [surface]."""
        iso_id = await self._resolve(surface)
        return await self._c.rpc(
            "ext.zee.tapByKey", {"isolateId": iso_id, "key": key}
        )


    async def speedcam_fixture(
        self,
        *,
        source: str,
        cam_type: str,
        lat: float,
        lon: float,
        event_id: str | None = None,
        maxspeed: int | None = None,
        host_lat: float | None = None,
        host_lon: float | None = None,
        speed_kmh: float | None = None,
        heading_deg: float | None = None,
        approach_m: float | None = None,
        last_seen_epoch_ms: int | None = None,
        clear: bool = True,
        surface: str = "dhu",
    ) -> dict[str, Any]:
        """0096: plant shaped SPEED|LANE cam via ext.zee.speedcam action=fixture."""
        iso_id = await self._resolve(surface)
        params: dict[str, Any] = {
            "isolateId": iso_id,
            "action": "fixture",
            "source": source,
            "camType": cam_type,
            "lat": str(lat),
            "lon": str(lon),
            "clear": "true" if clear else "false",
        }
        if event_id:
            params["eventId"] = event_id
        if maxspeed is not None:
            params["maxspeed"] = str(maxspeed)
        if host_lat is not None and host_lon is not None:
            params["hostLat"] = str(host_lat)
            params["hostLon"] = str(host_lon)
        if speed_kmh is not None:
            params["speedKmh"] = str(speed_kmh)
        if heading_deg is not None:
            params["headingDeg"] = str(heading_deg)
        if approach_m is not None:
            params["approachM"] = str(approach_m)
        if last_seen_epoch_ms is not None:
            params["lastSeenEpochMs"] = str(last_seen_epoch_ms)
        return await self._c.rpc("ext.zee.speedcam", params)

    async def speedcam_demo(
        self,
        *,
        on: bool = True,
        overlay: bool | None = True,
        surface: str = "dhu",
    ) -> dict[str, Any]:
        """0089: force Speedcam HUD Demo (+ optional DHU Overlay) without UI taps.

        ON  → ext.zee.speedcam action=demo overlay=true
        OFF → ext.zee.speedcam action=demoStop overlay=false
        Pass overlay=None to leave SpeedcamConfig.dhuSystemOverlay untouched.
        """
        iso_id = await self._resolve(surface)
        params: dict[str, Any] = {
            "isolateId": iso_id,
            "action": "demo" if on else "demoStop",
        }
        if overlay is not None:
            params["overlay"] = "true" if overlay else "false"
        return await self._c.rpc("ext.zee.speedcam", params)


    async def shot(
        self, surface: str, out_path: str | None = None
    ) -> dict[str, Any]:
        """Capture a PNG screenshot of [surface].

        If [out_path] is given the PNG is written there and the result dict
        contains `saved_to` instead of the raw base64 blob.
        """
        iso_id = await self._resolve(surface)
        result = await self._c.rpc("ext.zee.shot", {"isolateId": iso_id})
        if out_path and isinstance(result, dict) and "png_b64" in result:
            p = Path(out_path)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(base64.b64decode(result["png_b64"]))
            return {k: v for k, v in result.items() if k != "png_b64"} | {
                "saved_to": str(p)
            }
        return result

    # ------------------------------------------------------------------
    # inject — T1: VM-service → ext.zee.inject on DHU; T2/T3: native channel
    # ------------------------------------------------------------------

    async def inject(self, surface: str = "dhu", **kv: str) -> dict[str, Any]:
        """Inject a CarSignalEvent.

        On T1 (T1NativeStub): calls ext.zee.inject on the DHU VM isolate.
        On T2/T3 (T2NativeChannel): ADB broadcast → com.zeepowertoys.SIMULATE;
          the native simulator emits the event → bridge → Dart → relay → HUD.
        """
        if isinstance(self._native, T2NativeChannel):
            return await self._native.inject(kv)
        # T1: VM-service inject
        try:
            iso_id = await self._resolve(surface)
            params: dict[str, Any] = {"isolateId": iso_id}
            params.update(kv)
            return await self._c.rpc("ext.zee.inject", params)
        except NotImplementedError:
            # Explicit native fallback (should not happen on T1 with T1NativeStub)
            return await self._native.inject(kv)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _resolve(self, surface: str) -> str:
        """Return the isolateId for [surface], refreshing the map if needed."""
        if surface in self._surfaces:
            return self._surfaces[surface]
        # Surface not in cached map — re-resolve (handles late HUD startup).
        fresh = await _build_surface_map(self._c)
        self._surfaces.update(fresh)
        if surface in self._surfaces:
            return self._surfaces[surface]
        raise RuntimeError(
            f"surface '{surface}' not found; available: {list(self._surfaces)}"
        )


# ---------------------------------------------------------------------------
# Surface-map builder — polls until both dhu+hud answer (ADR 0004)
# ---------------------------------------------------------------------------

async def _build_surface_map(
    client: _z.VMClient,
    *,
    timeout_s: float = 30.0,
    poll_interval_s: float = 0.5,
) -> dict[str, str]:
    """Poll getVM until both surfaces answer ext.zee.whoami, return surface→isolateId."""
    import time

    deadline = time.monotonic() + timeout_s
    while True:
        isos = await client.isolates()
        surface_map: dict[str, str] = {}
        for iso in isos:
            try:
                res = await client.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
                surf = res.get("surface", "") if isinstance(res, dict) else ""
                if surf:
                    surface_map[surf] = iso["id"]
            except Exception:
                pass  # isolate starting up — retry below
        if "dhu" in surface_map and "hud" in surface_map:
            return surface_map
        if time.monotonic() > deadline:
            raise RuntimeError(
                f"timed out waiting for both surfaces; found: {list(surface_map)}"
            )
        await asyncio.sleep(poll_interval_s)


async def _open_feedback_loop(
    ws_uri: str | None,
    native: NativeChannel | None,
    fn,
) -> Any:
    """Open a VMClient connection, build the surface map, call fn(FeedbackLoop)."""
    if ws_uri is None:
        raise RuntimeError("ws_uri is required for VM-service operations")

    async def _inner(client: _z.VMClient) -> Any:
        surface_map = await _build_surface_map(client)
        loop = FeedbackLoop(
            client=client,
            surface_map=surface_map,
            native=native or T1NativeStub(),
        )
        return await fn(loop)

    return await _z._with_client(ws_uri, _inner)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_kvs(kvs: list[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for kv in kvs:
        if "=" not in kv:
            raise ValueError(f"bad param {kv!r} (expected key=value)")
        k, v = kv.split("=", 1)
        out[k] = v
    return out


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Tier-agnostic Feedback Loop client for zee-power-toys (ADR 0004)."
    )
    p.add_argument(
        "--vm-uri",
        default=None,
        help="VM-service URI override (else $ZEE_VM_URI / logcat scan)",
    )
    p.add_argument(
        "--serial",
        default=_z.DEFAULT_SERIAL,
        help="adb serial for Android targets (default: %(default)s)",
    )
    p.add_argument(
        "--tier",
        choices=["t1", "t2", "t3"],
        default="t1",
        help="target tier (default: t1); affects native-channel routing",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    # whoami-all
    sub.add_parser("whoami-all", help="call ext.zee.whoami on every isolate")

    # dump-state
    ds = sub.add_parser("dump-state", help="raw state dump for a surface")
    ds.add_argument("--surface", required=True, choices=["dhu", "hud"])

    # read-view-model
    rv = sub.add_parser("read-view-model", help="derived view-model for a surface")
    rv.add_argument("--surface", required=True, choices=["dhu", "hud"])

    # set-config
    sc = sub.add_parser("set-config", help="write config to a surface")
    sc.add_argument("--surface", required=True, choices=["dhu", "hud"])
    sc.add_argument("kvs", nargs="+", help="key=value pairs")

    # tap
    tap = sub.add_parser("tap", help="synthetic tap on a keyed widget")
    tap.add_argument("--surface", required=True, choices=["dhu", "hud"])
    tap.add_argument("--key", required=True, help="ValueKey string")

    # shot
    shot = sub.add_parser("shot", help="capture a PNG screenshot")
    shot.add_argument("--surface", required=True, choices=["dhu", "hud"])
    shot.add_argument("--out", default=None, help="path to save the PNG (optional)")
    shot.add_argument(
        "--layer",
        choices=["flutter", "native", "both"],
        default="flutter",
        help=(
            "flutter (default, unchanged behaviour): ext.zee.shot RepaintBoundary "
            "capture — CANNOT see the native minimap composite "
            "(docs/issues/0009-minimap-under-layer.md:39). "
            "native: full device composite via `adb exec-out screencap` (no VM "
            "session needed). both: writes native to --out and flutter to "
            "--out.flutter.png, reports both dimension pairs."
        ),
    )
    shot.add_argument(
        "--expect",
        default=None,
        help="WxH (e.g. 1024x576) — assert the native capture's dimensions; "
        "on mismatch nothing is written and the command exits non-zero",
    )

    # hud-display — discover the HUD secondary display (Block 0027).
    sub.add_parser(
        "hud-display",
        help="discover the HUD secondary display via `adb shell dumpsys display` "
        "(displayId/w/h/dpi) — pure adb, no VM session needed",
    )

    # inject — T1: VM-service ext.zee.inject on DHU; T2/T3: native channel
    inj = sub.add_parser(
        "inject",
        help="inject a CarSignalEvent (T1: VM-service ext.zee.inject; T2/T3: native channel)",
    )
    inj.add_argument(
        "--surface",
        default="dhu",
        choices=["dhu", "hud"],
        help="target surface for inject (default: dhu)",
    )
    inj.add_argument("kvs", nargs="+", help="key=value pairs e.g. kind=speed value=80")

    # native-dump — T2/T3: ADB broadcast to DUMP; returns native snapshot JSON
    sub.add_parser(
        "native-dump",
        help="(T2/T3) return native CarSignals snapshot JSON via DUMP broadcast",
    )

    # minimap — drive ext.zee.minimap on the DHU surface (Block 0009)
    mm = sub.add_parser(
        "minimap",
        help="drive native MinimapView via ext.zee.minimap on DHU (Block 0009)",
    )
    mm.add_argument("kvs", nargs="+", help="key=value pairs e.g. on=true x=0 y=0 w=640 h=360")


    # speedcam-fixture — 0096 shaped SPEED|LANE plant
    sf = sub.add_parser(
        "speedcam-fixture",
        help="(0096) plant shaped cam via ext.zee.speedcam action=fixture",
    )
    sf.add_argument("--surface", default="dhu", choices=["dhu", "hud"])
    sf.add_argument("--source", required=True, choices=["ynavi", "osm", "osm+ynavi"])
    sf.add_argument("--cam-type", required=True, dest="cam_type",
                    help="SPEED or LANE (or SPEED_CONTROL / LANE_CONTROL tags)")
    sf.add_argument("--lat", type=float, required=True)
    sf.add_argument("--lon", type=float, required=True)
    sf.add_argument("--event-id", dest="event_id", default=None)
    sf.add_argument("--maxspeed", type=int, default=None)
    sf.add_argument("--host-lat", type=float, default=None, dest="host_lat")
    sf.add_argument("--host-lon", type=float, default=None, dest="host_lon")
    sf.add_argument("--speed-kmh", type=float, default=None, dest="speed_kmh")
    sf.add_argument("--heading-deg", type=float, default=None, dest="heading_deg")
    sf.add_argument("--approach-m", type=float, default=None, dest="approach_m",
                    help="pose host this many metres south of planted cam")
    sf.add_argument("--no-clear", action="store_true",
                    help="keep prior harness cams (B dedupe re-inject)")
    sf.add_argument("--last-seen-epoch-ms", type=int, default=None,
                    dest="last_seen_epoch_ms",
                    help="aged lastSeen for C1/C2 TTL rows")

    # speedcam-demo — 0089 one-shot Demo (+ Overlay) without OCR/taps
    sd = sub.add_parser(
        "speedcam-demo",
        help="(0089) force Speedcam HUD Demo ON/OFF; optional DHU Overlay via "
        "ext.zee.speedcam action=demo|demoStop (no OCR/coordinate taps)",
    )
    sd.add_argument(
        "state",
        choices=["on", "off"],
        help="on = demo+overlay; off = clearPose + overlay false",
    )
    sd.add_argument(
        "--surface",
        default="dhu",
        choices=["dhu", "hud"],
        help="target surface (default: dhu)",
    )
    sd.add_argument(
        "--no-overlay",
        action="store_true",
        help="do not touch SpeedcamConfig.dhuSystemOverlay (demo pose only)",
    )


    return p


def main(argv: list[str] | None = None) -> int:
    p = build_parser()
    args = p.parse_args(argv)

    # hud-display is pure adb (dumpsys display) — no VM session, no tier.
    if args.cmd == "hud-display":
        try:
            info = _z.resolve_hud_display(serial=args.serial)
            print(json.dumps(info, indent=2))
            return 0
        except Exception as e:
            print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
            return 1

    # `shot --layer native` is also pure adb (screencap) — no VM session needed.
    if args.cmd == "shot" and args.layer == "native":
        expect = _parse_wxh(args.expect) if args.expect else None
        try:
            result = shot_native(args.surface, args.out, serial=args.serial, expect=expect)
        except Exception as e:
            print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
            return 1
        print(json.dumps(result, indent=2))
        return 1 if "error" in result else 0

    # Resolve VM URI (logcat/env/flag).
    # For native-dump on T2 we don't need the VM URI — but we still try to
    # resolve it (gracefully) so other commands work in the same session.
    ws_uri: str | None = None
    if args.cmd != "native-dump":
        try:
            ws_uri = _z.resolve_ws_uri(serial=args.serial, override=args.vm_uri, tier=args.tier)
        except Exception as e:
            print(
                json.dumps({"error": f"VM discovery failed: {e}"}, indent=2),
                file=sys.stderr,
            )
            return 3

    # Select native channel based on tier.
    # T2 (--tier t2) uses T2NativeChannel with the given --serial.
    # T1 uses the stub that raises on any native call.
    native: NativeChannel
    if args.tier in ("t2", "t3"):
        native = T2NativeChannel(serial=args.serial)
    else:
        native = T1NativeStub()

    # native-dump is a pure native-channel command — no VM session needed.
    if args.cmd == "native-dump":
        if not isinstance(native, T2NativeChannel):
            print(
                json.dumps({"error": "native-dump requires --tier t2 or t3"}, indent=2),
                file=sys.stderr,
            )
            return 3
        try:
            result = asyncio.run(native.dump())
            print(json.dumps(result, indent=2))
            return 0
        except Exception as e:
            print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
            return 1

    async def run(fl: FeedbackLoop) -> tuple[int, Any]:
        if args.cmd == "whoami-all":
            result = await fl.whoami_all()
        elif args.cmd == "dump-state":
            result = await fl.dump_state(args.surface)
        elif args.cmd == "read-view-model":
            result = await fl.read_view_model(args.surface)
        elif args.cmd == "set-config":
            kv = _parse_kvs(args.kvs)
            result = await fl.set_config(args.surface, **kv)
        elif args.cmd == "tap":
            result = await fl.tap(args.surface, args.key)
        elif args.cmd == "shot":
            # args.layer == "native" is handled earlier (no VM session needed);
            # here layer is "flutter" (default, unchanged behaviour) or "both".
            if args.layer == "both":
                expect = _parse_wxh(args.expect) if args.expect else None
                try:
                    native_result = shot_native(
                        args.surface, args.out, serial=args.serial, expect=expect,
                    )
                except Exception as e:
                    native_result = {"error": str(e)}
                flutter_out = f"{args.out}.flutter.png" if args.out else None
                flutter_result = await fl.shot(args.surface, out_path=flutter_out)
                result = {"native": native_result, "flutter": flutter_result}
            else:
                result = await fl.shot(args.surface, out_path=args.out)
        elif args.cmd == "inject":
            kv = _parse_kvs(args.kvs)
            surface = getattr(args, "surface", "dhu")
            result = await fl.inject(surface, **kv)
        elif args.cmd == "minimap":
            kv = _parse_kvs(args.kvs)
            iso_id = await fl._resolve("dhu")
            params: dict[str, Any] = {"isolateId": iso_id}
            params.update(kv)
            result = await fl._c.rpc("ext.zee.minimap", params)
        elif args.cmd == "speedcam-fixture":
            result = await fl.speedcam_fixture(
                source=args.source,
                cam_type=args.cam_type,
                lat=args.lat,
                lon=args.lon,
                event_id=args.event_id,
                maxspeed=args.maxspeed,
                host_lat=args.host_lat,
                host_lon=args.host_lon,
                speed_kmh=args.speed_kmh,
                heading_deg=args.heading_deg,
                approach_m=args.approach_m,
                last_seen_epoch_ms=args.last_seen_epoch_ms,
                clear=not args.no_clear,
                surface=args.surface,
            )
            print(json.dumps(result, indent=2))
        elif args.cmd == "speedcam-demo":
            overlay = None if args.no_overlay else (args.state == "on")
            # off always clears overlay unless --no-overlay
            if args.state == "off" and not args.no_overlay:
                overlay = False
            if args.state == "on" and not args.no_overlay:
                overlay = True
            result = await fl.speedcam_demo(
                on=(args.state == "on"),
                overlay=overlay,
                surface=args.surface,
            )
        else:
            raise ValueError(f"unknown command {args.cmd!r}")
        return 0, result

    try:
        rc, result = asyncio.run(_open_feedback_loop(ws_uri, native, run))
        if result is not None:
            print(json.dumps(result, indent=2))
        if (
            args.cmd == "shot"
            and args.layer == "both"
            and isinstance(result, dict)
            and "error" in result.get("native", {})
        ):
            return 1
        return rc
    except Exception as e:
        print(
            json.dumps({"error": str(e), "ws_uri": ws_uri}, indent=2),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

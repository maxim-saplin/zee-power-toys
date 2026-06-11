#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""feedback_loop.py — tier-agnostic Feedback Loop client (ADR 0004, Block 0002).

One class (`FeedbackLoop`) fronts semantic ops and routes each to the right
channel per tier.  T1 (Linux desktop) uses the VM-service channel for
everything; the native channel is a clean stub that refuses with an explicit
error — no fake success.  T2/T3 slot in by providing a real `NativeChannel`
implementation; call sites do not change.

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
  inject          key=value ...       (prints stub error on T1)

Examples:
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py whoami-all
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py tap --surface dhu --key dhu-toggle
  ZEE_VM_URI=ws://... uv run dev/feedback_loop.py inject foo=bar
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
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
            "Use set-config over the VM-service channel for T1 config writes."
        )


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
    # Native-channel op
    # ------------------------------------------------------------------

    async def inject(self, **kv: str) -> dict[str, Any]:
        """Inject config via the native channel.

        Raises on T1 with a clear explanation; succeeds on T2/T3.
        """
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
    ws_uri: str,
    native: NativeChannel | None,
    fn,
) -> Any:
    """Open a VMClient connection, build the surface map, call fn(FeedbackLoop)."""

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

    # inject (native channel)
    inj = sub.add_parser(
        "inject",
        help="inject config via the native channel (T2/T3 only; stub on T1)",
    )
    inj.add_argument("kvs", nargs="+", help="key=value pairs")

    return p


def main(argv: list[str] | None = None) -> int:
    p = build_parser()
    args = p.parse_args(argv)

    # Resolve VM URI (logcat/env/flag).
    try:
        ws_uri = _z.resolve_ws_uri(serial=args.serial, override=args.vm_uri)
    except Exception as e:
        print(
            json.dumps({"error": f"VM discovery failed: {e}"}, indent=2),
            file=sys.stderr,
        )
        return 3

    # The native channel is a stub on T1; future tiers supply a real impl.
    native: NativeChannel = T1NativeStub()
    # (T2/T3: replace with T2NativeChannel(serial=args.serial) etc.)

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
            result = await fl.shot(args.surface, out_path=args.out)
        elif args.cmd == "inject":
            kv = _parse_kvs(args.kvs)
            try:
                result = await fl.inject(**kv)
            except NotImplementedError as e:
                # Clean stub error — NOT a crash; exit 0 so callers can parse.
                print(json.dumps({"error": str(e)}, indent=2))
                return 0, None
        else:
            raise ValueError(f"unknown command {args.cmd!r}")
        return 0, result

    try:
        rc, result = asyncio.run(_open_feedback_loop(ws_uri, native, run))
        if result is not None:
            print(json.dumps(result, indent=2))
        return rc
    except Exception as e:
        print(
            json.dumps({"error": str(e), "ws_uri": ws_uri}, indent=2),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

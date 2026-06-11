#!/usr/bin/env python3
"""grab_shots.py — capture each engine's window via the VM-service ext.zee.shot.

No system window-grab tool exists under this WSLg setup, so each isolate renders
its own RepaintBoundary to a PNG and returns it base64 over the single VM
service. Writes shots/<surface>.png for every isolate that responds.
"""
import asyncio
import base64
import os
import sys

import zee_drive as z

OUT = os.path.join(os.path.dirname(__file__), "..", "shots")


async def run(c):
    os.makedirs(OUT, exist_ok=True)
    isos = await c.isolates()
    print(f"isolates: {len(isos)}")
    for iso in isos:
        try:
            r = await c.rpc("ext.zee.shot", {"isolateId": iso["id"]})
        except Exception as e:
            print(f"  {iso['id']}: shot RPC failed: {e}")
            continue
        if "png_b64" not in r:
            print(f"  {iso['id']}: no image -> {r}")
            continue
        png = base64.b64decode(r["png_b64"])
        path = os.path.join(OUT, f"{r['surface']}.png")
        with open(path, "wb") as f:
            f.write(png)
        print(f"  {r['surface']:>7}: {r['w']}x{r['h']}  {len(png)} bytes -> {os.path.relpath(path)}")


def main():
    asyncio.run(z._with_client(z.resolve_ws_uri(), run))
    return 0


if __name__ == "__main__":
    sys.exit(main())

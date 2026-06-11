#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""grab_shots.py — capture each engine's window via the VM-service ext.zee.shot.

Writes shots/hud-on.png, shots/hud-off.png, shots/dhu.png etc.
The caller sets hudBoxOn state before calling this script.
"""
from __future__ import annotations

import asyncio
import base64
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import zee_drive as z

OUT = os.path.join(os.path.dirname(__file__), '..', 'shots')


async def run(c: z.VMClient, label: str = '') -> None:
    os.makedirs(OUT, exist_ok=True)
    isos = await c.isolates()
    print(f'isolates: {len(isos)}')
    for iso in isos:
        try:
            r = await c.rpc('ext.zee.shot', {'isolateId': iso['id']})
        except Exception as e:
            print(f'  {iso["id"]}: shot RPC failed: {e}')
            continue
        if 'png_b64' not in r:
            print(f'  {iso["id"]}: no image -> {r}')
            continue
        png = base64.b64decode(r['png_b64'])
        surface = r.get('surface', iso['id'])
        filename = f'{surface}-{label}.png' if label else f'{surface}.png'
        path = os.path.join(OUT, filename)
        with open(path, 'wb') as f:
            f.write(png)
        print(f'  {surface:>7}: {r["w"]}x{r["h"]}  {len(png)} bytes -> {os.path.relpath(path)}')


def main() -> int:
    # Accept an optional label argument (e.g. 'on' or 'off') for filename suffix.
    label = sys.argv[1] if len(sys.argv) > 1 else ''
    asyncio.run(z._with_client(z.resolve_ws_uri(), lambda c: run(c, label)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

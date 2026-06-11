#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""verify_skeleton.py — smoke test for the walking-skeleton cross-isolate relay.

Proves:
  [1] Exactly 2 isolates on the VM.
  [2] Both surfaces (dhu, hud) are reachable via ext.zee.whoami.
  [3] Cross-isolate relay: setConfig hudBoxOn=true on DHU -> HUD dumpState shows true.
  [4] Relay reverse: setConfig hudBoxOn=false on DHU -> HUD flips back to false.

VM URI from $ZEE_VM_URI.
"""
from __future__ import annotations

import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import zee_drive as z


async def run(c: z.VMClient) -> dict:
    results: dict = {}

    # ---- [1] isolate count -----------------------------------------------
    isos = await c.isolates()
    results['isolate_count'] = len(isos)
    results['check_two_isolates'] = len(isos) == 2

    # ---- [2] surface map via whoami --------------------------------------
    surface_map: dict[str, str] = {}  # surface -> isolateId
    for iso in isos:
        try:
            w = await c.rpc('ext.zee.whoami', {'isolateId': iso['id']})
            surf = w.get('surface', '') if isinstance(w, dict) else ''
            if surf:
                surface_map[surf] = iso['id']
        except Exception as e:
            print(f'  whoami failed for {iso["id"]}: {e}', file=sys.stderr)

    results['surfaces_found'] = list(surface_map.keys())
    results['check_dhu_found'] = 'dhu' in surface_map
    results['check_hud_found'] = 'hud' in surface_map

    if not results['check_dhu_found'] or not results['check_hud_found']:
        results['pass'] = False
        results['error'] = 'missing dhu or hud surface'
        return results

    dhu_id = surface_map['dhu']
    hud_id = surface_map['hud']

    # ---- [3] relay true ---------------------------------------------------
    await c.rpc('ext.zee.setConfig', {'isolateId': dhu_id, 'hudBoxOn': 'true'})

    hud_on = False
    for _ in range(40):  # poll up to 4 s
        state = await c.rpc('ext.zee.dumpState', {'isolateId': hud_id})
        if isinstance(state, dict) and state.get('hudBoxOn') is True:
            hud_on = True
            break
        await asyncio.sleep(0.1)

    results['check_relay_true'] = hud_on

    # ---- [4] relay false --------------------------------------------------
    await c.rpc('ext.zee.setConfig', {'isolateId': dhu_id, 'hudBoxOn': 'false'})

    hud_off = False
    for _ in range(40):
        state = await c.rpc('ext.zee.dumpState', {'isolateId': hud_id})
        if isinstance(state, dict) and state.get('hudBoxOn') is False:
            hud_off = True
            break
        await asyncio.sleep(0.1)

    results['check_relay_false'] = hud_off

    # ---- summary ----------------------------------------------------------
    all_pass = all([
        results['check_two_isolates'],
        results['check_dhu_found'],
        results['check_hud_found'],
        results['check_relay_true'],
        results['check_relay_false'],
    ])
    results['pass'] = all_pass
    return results


def main() -> int:
    ws_uri = z.resolve_ws_uri()
    print(f'VM WebSocket: {ws_uri}', file=sys.stderr)
    results = asyncio.run(z._with_client(ws_uri, run))
    print(json.dumps(results, indent=2))
    return 0 if results.get('pass') else 1


if __name__ == '__main__':
    sys.exit(main())

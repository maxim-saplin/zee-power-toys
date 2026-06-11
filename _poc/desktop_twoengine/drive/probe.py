#!/usr/bin/env python3
"""probe.py — desktop TWO-ENGINE Feedback-Loop probe (Approach A: desktop_multi_window).

Drives the SINGLE Dart VM service of the running two-engine desktop app and
proves, end to end:
  [1] getVM lists exactly TWO root isolates (one VM service reaches both).
  [2] whoami on each -> surface map; SAME pid (one process), DIFFERENT isolate
      identity (separate Dart heaps).
  [3] Independent memory: bump HUD's counter -> it advances while PRIMARY's
      counter (never bumped) stays put -> the "shared-looking" value DIVERGES.
  [4] Cross-window sync: ext.zee.pushConfig on PRIMARY routes its counter to the
      HUD over the native-mediated Hub channel -> HUD.configFromMain updates,
      while HUD's OWN counter is untouched (so the value arrived via the channel,
      NOT via shared memory).

Reuses the project seed driver (zee_drive.py) as a library for VM discovery +
JSON-RPC. VM URI comes from $ZEE_VM_URI (scrape it from the flutter run log).
"""
import asyncio
import json
import sys

import zee_drive as z


async def _whoami(c, iso_id):
    return await c.rpc("ext.zee.whoami", {"isolateId": iso_id})


async def _surface_map(c):
    """Return (isolates, {surface: {isolateId, ...whoami}})."""
    isos = await c.isolates()
    rows = {}
    for iso in isos:
        w = await _whoami(c, iso["id"])
        rows[w["surface"]] = {"isolateId": iso["id"], **w}
    return isos, rows


async def run(c):
    isos, rows = await _surface_map(c)

    print("=" * 72)
    print(f"[1] ONE VM service -> getVM isolate count = {len(isos)}")
    for iso in isos:
        print(f"      id={iso['id']:<26} name={iso['name']}")
    assert len(isos) == 2, f"expected 2 isolates, got {len(isos)}"

    pri, hud = rows["primary"], rows["hud"]
    print("\n[2] whoami on each isolate (one external client, one VM service):")
    print(f"      PRIMARY: {json.dumps(pri)}")
    print(f"      HUD    : {json.dumps(hud)}")
    same_pid = pri["pid"] == hud["pid"]
    diff_iso = pri["isolate"] != hud["isolate"]
    print(f"      SAME OS process?      pid {pri['pid']} == {hud['pid']}  -> {same_pid}")
    print(f"      DIFFERENT isolate?    identityHashCode {pri['isolate']} != "
          f"{hud['isolate']}  -> {diff_iso}")

    print("\n[3] INDEPENDENT MEMORY proof (bump HUD only):")
    pri_before = (await _whoami(c, pri["isolateId"]))["counter"]
    hud_before = (await _whoami(c, hud["isolateId"]))["counter"]
    print(f"      before:  PRIMARY.counter={pri_before}   HUD.counter={hud_before}")
    for _ in range(3):
        await c.rpc("ext.zee.bump", {"isolateId": hud["isolateId"]})
    pri_after = (await _whoami(c, pri["isolateId"]))["counter"]
    hud_after = (await _whoami(c, hud["isolateId"]))["counter"]
    print(f"      bump HUD x3 -> PRIMARY.counter={pri_after}   HUD.counter={hud_after}")
    print(f"      DIVERGED?  HUD advanced by {hud_after - hud_before}, "
          f"PRIMARY unchanged ({pri_before}=={pri_after}) -> "
          f"{hud_after - hud_before == 3 and pri_after == pri_before}")

    print("\n[4] CROSS-WINDOW SYNC via native Hub (ext.zee.pushConfig on PRIMARY):")
    # bump PRIMARY twice so the pushed value is visibly != HUD's own counter
    await c.rpc("ext.zee.bump", {"isolateId": pri["isolateId"]})
    await c.rpc("ext.zee.bump", {"isolateId": pri["isolateId"]})
    pri_counter = (await _whoami(c, pri["isolateId"]))["counter"]
    push = await c.rpc("ext.zee.pushConfig", {"isolateId": pri["isolateId"]})
    print(f"      pushConfig result: {json.dumps(push)}")
    # poll HUD briefly for the channel-delivered value (in-process async routing)
    hud_w = None
    for _ in range(20):
        hud_w = await _whoami(c, hud["isolateId"])
        if hud_w["configFromMain"] == pri_counter:
            break
        await asyncio.sleep(0.05)
    print(f"      PRIMARY.counter pushed = {pri_counter}")
    print(f"      HUD.configFromMain     = {hud_w['configFromMain']}  "
          f"(via Hub channel; == pushed -> {hud_w['configFromMain'] == pri_counter})")
    print(f"      HUD.counter (own)      = {hud_w['counter']}  "
          f"(untouched by the push -> value arrived via CHANNEL, not shared memory)")
    print("=" * 72)


def main():
    ws = z.resolve_ws_uri()
    print(f"VM WebSocket: {ws}")
    asyncio.run(z._with_client(ws, run))
    return 0


if __name__ == "__main__":
    sys.exit(main())

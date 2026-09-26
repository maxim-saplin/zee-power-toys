# 0111 — Proposed next-drive dump script (T3 reconfirm)

Use only when a car session is available and firmware may have changed since
`eng.buildf.20251210` (2026-02-23 dumps). Do **not** steal Tablet from 0109/0110;
run on car DHU with existing phase0 / Toys diagnostics if present.

## When to sample

| Window | Driver action | Duration | Expect cluster |
|--------|---------------|----------|----------------|
| Standstill | P or brake hold, speed≈0 | 20 s | bar idle |
| Accel | Firm acceleration in D | 20–40 s | power side fills |
| Regen | Lift + brake regen | 20–40 s | regen side fills |
| Cruise | Steady speed, light pedal | 20 s | mid / low |

## Poll set (≤250 ms)

**Must stay sentinel if still dead:**
- Sensor: `0x00103600`, `0x00103500`, `0x00103300`, `0x00103400`, `0x00103100`, `0x00103200`
- Function int: `0x24215C00`, `0x241E5000`, `0x241E0500`, `0x241D2500`, `0x24010200`
- Customize float ZONE_GLOBAL=`0x80000000`: `0x2420C000`, `0x24140100`, `0x24140200` (expect 0 while not charging)

**Live anchors:**
- Sensor float: speed `0x00100100`, brake `0x00101300`, accel `0x00101400`
- Function int: power_flow `0x24010100` (log raw enum)

## Minimal adb one-liner sketch (Toys / phase0 probe)

Prefer existing `power_magnitude` probe group if APK still on car:

```bash
# Example — adjust package/activity to current diagnostics APK
adb shell am broadcast -a com.zeekr.phase0.RUN_PROBES --es probes power_magnitude
# pull JSON from app files / logcat tag PowerMagnitude*
```

Or logcat+API browser snapshot every 250 ms while Maxim drives the three windows; save under
`tmp/qa/0111-instant-power/t3-<date>/`.

## Pass / fail for reconfirm

- **Still dead:** regen A/B + discharge_power remain 255 across all three windows while anchors move → prior verdict stands.
- **Unblocked:** any of those IDs (or a new customize float) tracks with accel/regen non-sentinel and correlates with cluster → reopen spike, update knowledge, consider HUD follow-on.

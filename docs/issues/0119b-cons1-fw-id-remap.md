---
status: superseded-by-0119c — 03300/7.8 WRONG (DCDC ≠ dash Cons)
tip:
labels: [hud, battery, range, adapt-cons, cons1, firmware]
created: 2026-09-27
satisfies: Cons1 FW ID remap — bind trip cons ~7.8 so Cons Est leaves null
tier: T3
owner: zee-dev
blocked-by: []
modules: [AdaptApiCarSignals, publishEfficiency, estimatedRangeKmProvider]
priority: now
filed-by: zee-dev
related: [0118, 0119]
parent: [0119]
---

# 0119b — Cons1 FW ID remap (dashes RCA)

## Verified root cause (T3 2026-09-27)

After 0119 tip `a73fd73` (HUD seed + Cons-only), HUD still showed `70% · … km`. Native log:

`Battery seed: … cons1=null`

Not a missing HUD seed. `readSensorFloat(0x00103100)` returns **~650.7** (aux-like). `publishEfficiency` correctly rejects `≥ 200` as kWh/100 → Dart `efficiencyKwhPer100km` stays null → Cons Est null → pending ellipsis.

The session claim "Cons1=7.8 LIVE" was an **AdaptL dump mislabel**:

| function | hex | raw | scrape label (wrong) | reality on 20260318 |
|----------|-----|-----|----------------------|---------------------|
| 1061120 | `0x00103100` | ~651 | aux | classic Cons1 ID — junk as kWh/100 |
| 1061632 | `0x00103300` | **7.8** | cons1 | trip cons (classic Aux DCDC ID) |
| 1061888 | `0x00103400` | 16.6 | cons2 | secondary trip-ish |

## Fix

`AdaptApiCarSignals.readCons1KwhPer100()`: try classic `0x00103100` when in-band `(0,200)`; else alt `0x00103300`. Keep rejecting 650 junk. Register listener on both IDs. Log `publishEfficiency cons1=…` / out-of-band rejects.

## DoD

- [x] Native binds in-band Cons (~7.8) into snapshot / EfficiencyEvent.
- [x] Dart still rejects 650; accepts 7.8 (unit test).
- [ ] Car: `Battery seed: … cons1≈7.8` (not null); HUD digits leave `…`.
- [x] Live stays **1.1.0+26**; tip to main; no Own-fallback regression.

## Soft

Pack 100 vs AAOS ~150; instant power; Cons lag — unchanged.

## Superseded (2026-09-27)

Maxim HARD FAIL: alt `0x00103300` ~7.8 is DCDC, not trip Cons (dash ~24.5). See `0119c-remove-range-feature.md` — range feature removed entirely.

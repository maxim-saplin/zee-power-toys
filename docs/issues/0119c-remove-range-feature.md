---
status: accepted
tip: 0c69ee5
accepted: 2026-09-27
labels: [hud, battery, range, remove, rca]
created: 2026-09-27
satisfies: Remove HUD/settings range feature — Own Est + Cons Est gone; RCA tip
tier: T2
owner: zee-dev
blocked-by: []
modules: [BatteryWidget, hud_settings_screen, estimatedRangeKmProvider, AdaptApiCarSignals]
priority: now
filed-by: zee-pdm
related: [0105, 0107, 0108, 0114, 0117, 0118, 0119, 0119b]
parent: [0119b]
---

# 0119c — Remove range feature (RCA + product kill)

## RCA (T3 2026-09-27 — HARD)

1. **Own Est is unreliable** — no honest Wh/km from SoCΔ÷distance on car (bands / ~50 km window / soft 100 kWh pack). HUD Own digits do not match driver-trustworthy range.
2. **0119b Cons bind was wrong** — `0x00103300` ~7.8 is **DCDC_PWR_CNS1** (aux), **not** dash trip Cons. HUD ~897 km @70%/100 kWh matched 7.8 math; car dash trip Cons showed **~24.5 kWh/100** (last ~6 km) → expected Cons Est ~**286 km**.
3. **Classic `0x00103100`** tonight reads **~652** (OOB junk as kWh/100; may be unrelated). Older FW had in-band ~52–54 on that ID — **not** dash trip Cons either (tripCard `trip1AverageEnergy` / `trip2AverageEnergy` historically ~27–30).
4. **No AdaptAPI sensor ID matched dash ~24.5** in the live EnergySensor / AdaptL window (Cons chase abandoned). Trip-card averages live on VehicleCondition / Setting remote paths, not a proven DYN_EGY bind for Toys.

## Product (Maxim HARD 2026-09-27)

**Remove the range feature entirely** — not Adapt-Cons-only:

- Kill range on HUD (`N% · N km` / `… km`) — SoC % only.
- Kill settings range toggle + Cons Est readout.
- Own Est bands / 50 km window / Cons Est HUD path — gone from product surface.
- Live bump **1.1.0+27** after tip (Maxim GO).

## DoD

- [x] RCA documented (this file).
- [x] HUD shows battery % without range km / pending ellipsis.
- [x] Settings: no range toggle / Cons km readout.
- [x] Tip to `origin/main`; then Live **1.1.0+27**.
- [x] Soft: USB (optional — not required for tip) `adb install -r` optional after tip/release.

## Soft / out of scope

- Re-binding Adapt Cons / trip-card Cons for a future range Block.
- Instant power magnitude.
- Pack Wh hardcode cleanup beyond range removal.

## ACCEPT (PDM 2026-09-27)

Tip `0c69ee5` (0120 / 0119c remove-range). Live **1.1.0+27** tip `0066daf` APK sha256 `4d140b402415d32a4434e9bcbaf4b58a9562217aa25e3309c43a4acf6009c72a`. HUD SoC % only; settings range toggle + Cons Est gone; Cons DCDC alt bind dropped. Soft: prefs/l10n leftover (`showOwnRangeEstimate` keys), SHARED_USER keep-data `adb install -r`, car T3. No version bump in this seal.

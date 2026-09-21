# 0067 — Grow HUD battery cluster while charging

## Problem
While charging, the battery slot still used the 2-line geometry (SoC + temp).
Adding bolt/kW made a 3-line cluster that FittedBox crushed — barely readable.

## Fix
- `kBatterySlotHeightFracCharging` (0.82) and `kBatterySlotWidthFracCharging` (0.15)
- `batteryClusterSlotFracs(chargingStatsVisible:)` selects fracs
- `HudRoot` watches `chargingProvider` + `showChargingStats` and grows the slot
- Non-charging layout unchanged (0.12 × 0.6)

## Verify
Car charging: bolt/kW + SoC + temp all legible on HUD. Unplug → prior size.

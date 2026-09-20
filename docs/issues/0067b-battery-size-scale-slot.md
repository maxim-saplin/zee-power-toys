# 0067b — Battery sizeScale monotonic (no reverse shrink)

## Problem
Maxim: past ~1.5× sizeScale the battery section shrinks again.
Cause: marks grew with `sizeScale` inside a fixed slot; `FittedBox(scaleDown)`
crushed them when content exceeded the box.

## Fix
1. `batteryClusterSlotFracs` multiplies width/height by `sizeScale` (capped).
2. **Remove** `FittedBox(scaleDown)` from `BatteryWidget` — use `Align` so
   sizeScale is honest. Slot growth + no crush = monotonic visual size.

## Verify
Charge on; sweep sizeScale 1.0 → 1.5 → 2.0 — never reverse-shrinks; 3 lines legible.

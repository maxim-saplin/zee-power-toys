# 0068 — Charge UI dashes while raw had charging/kW

## Problem
Diagnostics Energy showed "—" for Charging / Charge power while Raw Snapshot
listed `charging: true` and `chargeKw: ±120`.

## Cause
Providers preferred `carSignalEventsProvider.value` when it was a `ChargeEvent`.
Later Speed/Battery events (or ChargeEvents with null kW) made `.value` the
wrong shape; Energy gated kW on `charging == true && chargeKw != null`.

## Fix
- All live signal providers read **snapshot** only; stream is a rebuild trigger.
- Energy Charge power shows whenever `chargeKw != null` (signed).
- CI: commit public AOSP `androiddebugkey.jks` so GH `flutter build apk --release` works with `useAospDebugKey=true`.

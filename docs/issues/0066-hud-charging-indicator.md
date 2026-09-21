---
status: done
labels: [hud, battery, charging, t3]
created: 2026-09-20
satisfies: HUD · utility info — charging stats
blocked-by: [0008]
modules: [AdaptApiCarSignals, chargingProvider, BatteryWidget]
tier: T3
owner: zee-dev
---

# 0066 — HUD charging indicator (live CHARGE_STATE)

## Block scope
Live car charging: HUD SoC/temp OK, but **no bolt / no charging stats**.
Diagnostics Energy → Charging `false`, Charge power `— kW`.

## Root cause
`AdaptApiCarSignals.registerListeners` handled `onSensorEventChanged` for
`CHARGE_STATE` (`0x00201500`) but **never registered** that sensor ID with
`ISensor.registerListener`. Bolt / stats gate on `chargingProvider==true`.
Same class of gap as SoC before seed+poll: listeners alone often never fire
until a change, so even registration needs `getSensorEvent` seed + slow poll.

## Fix
1. Register `CHARGE_STATE` alongside SPEED/SoC/temp on `ISensor.registerListener`.
2. Seed + poll `getSensorEvent(0x00201500)`; `event==1` → charging.
3. Seed + poll live charge V/A/kW via `getCustomizeFunctionValue(..., ZONE_GLOBAL)`
   so Diagnostics / HUD kW are not stuck at `—` waiting for a callback.

## Enum mapping
| `getSensorEvent(0x00201500)` | App |
|------------------------------|-----|
| `1` | charging (`chargingProvider=true`) |
| other / null | not charging |

Source: existing AdaptApi comment + `docs/knowledge/car-signals-adaptapi.md`
(Battery State / EnergyProbe — charging/discharging/idle via `getSensorEvent`).

## Definition of Done
- [x] CHARGE_STATE registered + seed/poll (mirrors SoC path)
- [x] Charge V/A/kW seed/poll
- [x] Issue + BACKLOG
- [ ] T3 QA: car charging → Diagnostics Charging true + kW; HUD bolt + stats
  (parent `adb install -r` immediately after tip)

## QA verify notes
1. Plug in / start charge on car.
2. Diagnostics → Energy: **Charging true**, Charge power shows kW (not `—`).
3. HUD: bolt + charging stats row when `showChargingStats` on.
4. Logcat `ZEE`: `Charge seed: event=1 charging=true ... kW=...`

## FAIL follow-up (Maxim 2026-09-20)
`event == 1` was wrong. zee_hud_2 ENERGY_SIGNAL_ANALYSIS: charging enums are
2102530 / 2102545 / 2102546 (etc.). Maxim saw `chargeKw` in raw snapshot while
`charging: false` — confirms V/A/kW path OK, flag decode broken.

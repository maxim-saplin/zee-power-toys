---
status: done
labels: [hud, battery]
created: 2026-09-20
satisfies: HUD · utility info — battery free placement
blocked-by: [0008]
modules: [ConfigStore, hud]
tier: T1
---

# 0051 — Free placement for battery HUD stats

## Block scope
Battery cluster (icon + % + **temp** + **charging kW**) freely placeable on the HUD — left/right and up/down — with named presets **left**, **right**, **right-top** (default = today's hard-coded top-right). DHU HUD settings expose presets + fine adjust. Looks/styles unchanged.

## Touches
- **Satisfies:** HUD utility info — placeable battery cluster
- **Modules:** ConfigStore (`BatteryConfig` / `BatteryPlacement`), `hud/hud_root.dart`, `hud/battery_widget.dart`, `hud/battery_geometry.dart`, `hud_settings_screen.dart`
- **ADRs:** 0001 (emissive HUD), 0003/0006
- **Prior art:** blinker `vertFrac` / `horizBiasFrac` / `sidePadFrac`; minimap named presets

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [x] Config for battery position (placement preset + vert/sidePad/horizBias fine adjust)
- [x] Presets: left, right, right-top (default = current top-right look)
- [x] Temp + charging kW move with the battery cluster (same `BatteryWidget` Column)
- [x] DHU HUD settings UI for presets + free adjust
- [x] analyze clean + focused geometry test
- [x] Tip on `0044-publish-prep`; push; report SHA

## Reconciliation
Issue file was missing on tip `d113e76` — authored from Maxim's 0051 brief + DoD. Mac `machineId` unavailable in this agent; built on box checkout of `0044-publish-prep`.

## Notes
Do **not** start 0045. Do not change battery pack looks/styles.

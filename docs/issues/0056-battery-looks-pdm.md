---
status: done
labels: [hud, battery]
created: 2026-09-20
satisfies: HUD · utility info — battery looks
blocked-by: [0051]
modules: [ConfigStore, hud, HudSettings]
tier: T1
owner: zee-dev
---

# 0056 — Battery looks (PDM names) + squarish bold outline

## Block scope
Product battery looks as named by PDM (single picker, not Content×Style matrix):

1. **Battery** — filled pack (icon only, continuous fill)
2. **Battery + text** — pack with %
3. **Battery with bars** — segmented
4. **Just text** — % only

Pack chrome: **squarish bold outline** (thicker stroke, tight corners). Default =
**Battery + text**. Legacy `contentMode`/`style` prefs migrate into `BatteryLook`.

## Touches
- **Satisfies:** REQUIREMENTS — battery looks (Steam-Deck-adjacent; PDM naming)
- **Modules:** `BatteryConfig` / `BatteryLook`, `battery_widget.dart`,
  `hud_settings_screen.dart`, l10n EN/RU, Feedback Loop `batteryLook`
- **ADRs:** 0001 (emissive HUD), 0003
- **Prior:** [0008](0008-battery-charging.md), [0051](0051-battery-free-placement.md)

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [x] `BatteryLook` enum + `withLook` syncs contentMode/style
- [x] DHU HUD settings: one Look picker with the four PDM names (EN/RU)
- [x] Painter: squarish bold outline
- [x] Legacy prefs without `look` migrate; FL accepts `batteryLook`
- [x] analyze + battery widget tests green
- [x] Tip on `0044-publish-prep`; car install = `adb install -r` only (0054)

## Reconciliation
0055 minimap guidance overlay stays on tip — do not drop. 0054 keep-data via
signing/`-r` remains install policy.

## Notes
Queued next: **0057** — show minimap only while YNavi guidance active (default off).

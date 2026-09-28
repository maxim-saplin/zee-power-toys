---
status: tip-ready
labels: [hud, battery, defaults, charging]
created: 2026-09-28
satisfies: HUD-on battery defaults — % + temp bottom-right; charging row stacks above without moving bottom
tier: T2
owner: zee-dev
blocked-by: []
modules: [BatteryWidget, hud_settings_screen, HudConfig]
priority: soon
filed-by: zee-pdm
related: [0104, 0105, 0119c]
---

# 0120 — HUD battery defaults (when HUD enabled)

## Product (Maxim 2026-09-28)

When HUD is enabled, fresh/default battery presentation:

1. **Percent** (battery + text / pct visible — not bars-only / not just-text as the silent default).
2. Placement: **bottom-right corner**, with **temperature** shown with the battery.
3. When **charging**, charging stats / power display **on top of** the percentage — **add a row above**; **do not move the bottom edge** of the battery block (anchor bottom; grow upward).

## DoD

- [x] New / reset HUD-on defaults: % + temp, bottom-right.
- [x] Charging: power/stats row stacks **above** %; bottom of block stays put.
- [x] T2 dens320 Tablet shots (idle + charging inject) prove layout.
- [x] Tip to `origin/main`.

## Soft / out of scope

- Range Est (removed 0119c).
- Live bump only Maxim GO — hold **1.1.0+27**.

## DEV tip (2026-09-28 Europe/Minsk)

- Defaults: `BatteryLook.batteryText` + `showTemp` + **`BatteryPlacement.rightBottom`** (bottom-anchor; charging grows up).
- Column: charging stats **above** pack/%; Align bottom on rightBottom.
- Evidence: `tmp/qa/0120-cut-dev/` — idle `10-idle-defaults.png` (72%+31°C BR); charging `20-charging-stack.png` (11 kW above); `pixel-bbox.txt` bottom_delta=0.
- Soft: range gone (0119c); Live hold **1.1.0+27**.
- Who-next: **@zee-qa**.

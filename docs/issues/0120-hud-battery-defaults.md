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

- [ ] New / reset HUD-on defaults: % + temp, bottom-right.
- [ ] Charging: power/stats row stacks **above** %; bottom of block stays put.
- [ ] T2 dens320 Tablet shots (idle + charging inject) prove layout.
- [ ] Tip to `origin/main`.

## Soft / out of scope

- Range Est (removed 0119c).
- Live bump only if product needs it after tip (Maxim GO).

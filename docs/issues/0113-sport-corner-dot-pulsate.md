---
status: open
labels: [hud, adapt, drive-mode]
created: 2026-09-26
satisfies: Sport red corner-dot pulsates; ECO/Comfort stay calm
tier: T2
owner: zee-dev
blocked-by: [0112]
modules: [DriveModeCornerDot, HudRoot]
priority: now
filed-by: zee-pdm
related: [0110, 0112]
parent: [0110]
gate: armed-2026-09-26
---

# 0113 — Sport corner-dot pulsates; ECO/Comfort calm

## Block scope

Maxim 2026-09-26 ~13:18 Minsk: when the persistent drive-mode corner-dot is ON, the **Sport** (spirit) **red** dot must **pulsate**; ECO and Comfort dots stay **calm** (steady).

## Product rules

1. Requires **0112** Sport = red on the corner-dot (no yellow).
2. Pulse is gentle, readable at a glance, not seizure-fast; ECO/Comfort opacity/size stay fixed.
3. Toggle OFF → no dot. Unknown/other → hide (existing 0110).
4. Preview / Simulated must show Sport pulse on T2.

## DoD (T2 dens320)

- [ ] ON + Sport → red pulsating BR dot
- [ ] ON + ECO / Comfort → calm blue / green (no pulse)
- [ ] OFF / unknown → no pulse chrome
- [ ] Soft: car T3; pulse timing taste OK

## Soft / residuals

- Exact pulse period left to zee-dev taste unless Maxim names Hz; document chosen period in tip.

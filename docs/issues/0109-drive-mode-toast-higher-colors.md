---
status: ready-for-agent
labels: [hud, adapt, drive-mode, polish]
created: 2026-09-26
satisfies: foundation
blocked-by: []
modules: [DriveModeToastLayer, DriveModeMapping, HudHost]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
gate: armed-2026-09-26
related: [0104]
parent: [0104]
---

# 0109 — Drive-mode toast higher + blue/green/red accents

## Block scope

Maxim 2026-09-26 ~09:33 Minsk (after Live 1.1.0+22):

1. Raise the HUD drive-mode change toast **slightly higher** — it currently **crosses the speedo**.
2. Recolor the three modes: **blue / green / red** (one solid accent per mode). Drop the current cyan/orange 0104 palette.

**Does not** add a permanent badge (that is **0110**). Change-only toast chrome; keep 0104 change-only / ~5 s / fade / cold-open silence rules.

## Product mapping (HARD)

| Mode | Accent |
|------|--------|
| ECO | **green** |
| Comfort | **blue** |
| Sport | **red** |
| other / unknown | soft grey (no invent) |

Keep Adapt `0x22010100` mapping from 0104. Labels unchanged (ECO / Comfort / Sport).

## Position

- Move toast **up** within Safe Area / top-centre stack so it clears the speedo cluster on Tablet dens320 HUD and DHU geometry.
- Still clear of blinkers / Alien radar / battery.
- Measure on T2 Tablet dens320 (never `wm density`); soft car T3 after.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] Toast sits **above** the speedo region (no overlap on Tablet dens320 HUD shot) — evidence crop shows clearance.
- [ ] ECO=green, Comfort=blue, Sport=red on toast chrome (glyph/label accent).
- [ ] 0104 behaviour preserved: change-only; cold-open / first-known silent; ~5 s then fade; same-mode silent.
- [ ] Simulated Settings / inject still fires ECO / Comfort / Sport for T2.
- [ ] Unit / widget fixtures for accent colors if present; analyze clean on touched Dart.
- [ ] QA FINDINGS on tip + beta four-point + PDM ACCEPT after own-check. Soft: car T3.

## Notes

- Cooking: tip OK; **no Live bump** until Maxim GO after ACCEPT.
- Do **not** implement 0110 persistent corner dot here — leave that for 0110.
- Prefer cut **before** 0110 if one Tablet contested.

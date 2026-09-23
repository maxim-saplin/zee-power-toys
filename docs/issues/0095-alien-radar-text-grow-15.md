---
status: open
labels: [hud, alien, crt, ui]
created: 2026-09-23
satisfies: polish
blocked-by: []
modules: [speedcam_radar_widget]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0083
---

# 0095 — Grow Alien radar text by 15%

## Block scope
Maxim 2026-09-23: grow the **Alien** CRT radar readout text by **15%** (km + speed-limit stack).

## Knob (main today)
`lib/hud/speedcam_radar_widget.dart`:
- `kAlienCrtKmDesignFont = 34.0` → **39.1** (×1.15)
- `kAlienCrtLimitDesignFont = 18.0` → **20.7** (×1.15)

Keep DPI-agnostic plate scaling (`alienCrtPlateScale`); do **not** reintroduce density bridges. Apply equally on HUD / DHU preview / Overlay (same painter).

## Definition of Done
- [ ] Design fonts ×1.15 on tip
- [ ] T2 evidence: HUD + DHU preview + Overlay CRT screenshots (same Demo pose) vs tip parent — text visibly ~15% larger, layout still readable (bottom-left, even fan pad)
- [ ] QA FINDINGS; beta four-point; PDM ACCEPT after own pixel check

## Notes
- 0083 bar was LARGE type (~0.21 of min-side). This is a further +15% on that tune, not a shrink.
- Prefer `speedcam-demo` harness (0094) for Demo+Overlay shots.

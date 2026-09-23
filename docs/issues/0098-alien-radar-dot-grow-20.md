---
status: ready-for-agent
labels: [hud, alien, crt, ui]
created: 2026-09-23
satisfies: polish
blocked-by: []
modules: [speedcam_radar_widget]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0095
---

# 0098 — Grow Alien radar center-dot diameter by 20%

## Block scope
Maxim 2026-09-23: grow the **Alien** CRT radar **center dot** (bright pip at the fan origin) by **20% diameter**.

## Knob (main today)
`lib/hud/speedcam_radar_widget.dart` center pip:
```dart
canvas.drawCircle(c, 4 * s, Paint()..color = SpeedcamRadarWidget.phosphorGlow);
canvas.drawCircle(c, 2 * s, Paint()..color = const Color(0xFFE8FFE8));
```
Diameter ×1.20 ⇒ radii ×1.20: **4 → 4.8**, **2 → 2.4** (or named consts). Keep DPI-agnostic plate scaling (`s` / `alienCrtPlateScale`); do **not** reintroduce density bridges. Apply equally on HUD / DHU preview / Overlay (same painter).

**Out of scope:** blips, fan arcs, grit, scanlines, km/limit text (0095 already +15%).

## Definition of Done
- [ ] Design radii ×1.20 on tip
- [ ] T2 evidence: HUD + DHU preview + Overlay CRT screenshots (same Demo pose) vs tip parent — center pip visibly ~20% larger; fan pad / layout still readable
- [ ] QA FINDINGS; beta four-point; PDM ACCEPT after own pixel check

## Notes
- Prefer `speedcam-demo` harness (0094) for Demo+Overlay shots.
- Parallel grind with 0097 C1 (Live toys bridge) — UI cut does not block C1.
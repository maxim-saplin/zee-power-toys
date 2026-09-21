---
status: ready-for-agent
labels: [speedcam, hud, overlay, dhu, alien]
created: 2026-09-22
satisfies: Honest Alien radar preview (DHU/overlay = HUD) + overlay size/position when overlay ON
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedcamRadarWidget, Speedcam settings preview, SpeedcamSystemOverlay]
priority: now
filed-by: zee-pdm
---

# 0079 — Alien preview honesty + overlay size/position

## Why
Maxim: Alien Speedcam **preview on DHU/settings is not honest** — HUD looks nicer / different than what Overlay/DHU preview shows. Also: when **DHU system overlay** is toggled ON, expose **size** and **location** customization for that overlay.

## Scope
1. **Preview parity (Alien):** settings / DHU preview must match what HUD actually paints for Alien (geometry, colors, motion cues as product intends) — no “prettier HUD / worse preview” gap. Default look stays honest too if touched.
2. **Overlay layout:** when overlay toggle ON, enable controls for **size** and **location** (reuse battery-style presets / free place if that pattern fits; fail loud, persist). When overlay OFF, hide or disable those controls.
3. EN+RU. T2 pixels: preview vs HUD Alien; overlay size/pos on emu.

## Out of scope
- Rewriting Alien look from scratch unless needed for parity
- Car T3 (note for later)
- 0078 v30 port (parallel, don’t starve)

## DoD
- [ ] Alien: side-by-side HUD vs settings/overlay preview — same look (QA pixels)
- [ ] Overlay OFF → no size/pos chrome (or clearly disabled)
- [ ] Overlay ON → size + location change the overlay; persist across relaunch
- [ ] QA FINDINGS + PDM ACCEPT

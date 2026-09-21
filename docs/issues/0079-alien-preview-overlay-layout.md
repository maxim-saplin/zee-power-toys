---
status: cooking
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

## Cooking
- Alien settings preview + system overlay use `hudCompact` (HUD paint path); no idle alwaysShow CRT on overlay.
- Overlay ON → size slider (0.6–1.6×) + TL/TR/BL/BR placement; OFF → chrome hidden.
- Prefs persist via `SpeedcamConfig.overlaySizeScale` / `overlayPlacement`.

## DoD
- [ ] Alien: side-by-side HUD vs settings/overlay preview — same look (QA pixels)
- [ ] Overlay OFF → no size/pos chrome (or clearly disabled)
- [ ] Overlay ON → size + location change the overlay; persist across relaunch
- [ ] QA FINDINGS + PDM ACCEPT

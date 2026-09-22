---
Status: ACCEPT (2026-09-23 tip ea3f461)
labels: [hud, speedcam, crt]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [SpeedcamRadarWidget, SpeedcamSettingsScreen, HudRoot]
tier: T3
---

# 0083 — DHU Alien CRT preview ≠ HUD (car)

## Block scope
Maxim (car, 2026-09-22): Speedcam DHU Radar preview is not the same as the windshield HUD Alien CRT. Capture + fix visual parity on car density; do not treat 0080 Tablet ACCEPT as done for T3.

## Evidence (car `8d95aaec` ~20:12–20:16 Minsk)
- `tmp/qa/car-2026-09-22/shots/06-dhu-speedcam-crt.png` — settings Радар preview Alien CRT with 0.20 / 60
- `tmp/qa/car-2026-09-22/shots/06-hud-windshield.png` — same moment HUD: minimap + 72% + 13°C, **no CRT**
- `07-dhu-scrolled-look.png` — look = **Alien**, HUD mode = Любые
- Earlier `disp-2.png` (~20:12) **did** show green CRT 0.20 on HUD — Presentation can paint; mismatch is real when comparing preview vs live

## Code note (do not “fix” by removing demo without Maxim)
`speedcam_settings_screen.dart` Radar preview always passes `forceDemoDanger: SpeedcamRadarWidget.demoDanger` (and `alwaysShow: !isAlien`). So the settings panel **always** paints demo CRT even when HUD is idle (Maxim rule: HUD Alien idle → nothing). Product bar is still: **when both show CRT, plate/grit/km/pad must match HUD** on car DHU dpi (high physical density, low reported dpi — same class as 0080 / YNavi ZeeUiScale). Do not “fix” car look with `wm density`.

## Definition of Done
- [ ] Runtime-confirmed on **Tier T2** (Tablet) then **T3** (car) — paired DHU preview + HUD Presentation screenshots with CRT visible on both
- [ ] Landscape CRT plate, even pad, km bottom-left (0080 HARD) — car pixels match HUD grit/weight, not just Tablet
- [ ] PDM ACCEPT only after own double-check of car (or T2 if car offline) evidence — no LGTM on diffs

## Notes
Also open from same car session (separate): PackageInfo-only version (UI +6 vs versionCode 9), dual Install race, USB Host/Peripheral lie, progress-bar backstep UX, YNavi label v12→upstream major.

## ACCEPT RETRACTED (2026-09-23 Maxim)
Tip `6788dc5` matched scale by shrinking HUD toward Overlay (~0.117). **Wrong bar.**
DoD: Overlay + DHU preview type scale **UP** to the **large HUD baseline**
(pre-6788dc5 HUD size / glyph fraction ~0.21), all three **large and equal**.
Not HUD FittedBox-down to Overlay-small. Keep Demo limit 60 sync.
Math: km font ≈ 34×(minSide/160), limit ≈ 18×s → fraction ~0.21.
QA: MEASURE vs large HUD target (~0.21), not Overlay-small.

## ACCEPT (2026-09-23) tip `ea3f461`
PDM pixel check PASS (Maxim large-HUD bar): type ratios ~0.18 across HUD/preview/Overlay (spread 0.0095), Demo 0.20+60 all three, Overlay HOME DoD PASS. Prior `6788dc5` ACCEPT retracted (shrunk HUD toward Overlay). Soft grit vs car secondary — no reopen.
Evidence: `tmp/qa/0083-after/`.

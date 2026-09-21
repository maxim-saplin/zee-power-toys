---
status: in-progress
labels: [speedcam, dhu, overlay]
created: 2026-09-20
satisfies: Speedcam system overlay on DHU + toggle
tier: T2
owner: zee-dev
---

# 0065 — Speedcam DHU system overlay

## Scope
Always-on-top Speedcam alert plate on the **DHU** via `TYPE_APPLICATION_OVERLAY`
(+ `SYSTEM_ALERT_WINDOW`), gated by settings toggle `SpeedcamConfig.dhuSystemOverlay`.

## Behaviour
- Toggle off by default.
- When on + permission granted: show floating plate while an approach-radius
  danger matches HUD presence mode; hide otherwise.
- Permission: `Settings.canDrawOverlays` / `ACTION_MANAGE_OVERLAY_PERMISSION`.

## T2 DoD
- [x] Manifest + Kotlin WindowManager controller + MethodChannel
- [x] Settings toggle + config persistence
- [ ] Emulator: grant overlay, Demo approach → plate visible over launcher
- [ ] analyze + tests green

## Out of scope (T3)
- Pixel-perfect CRT radar in the overlay window
- Maxim car eyeball

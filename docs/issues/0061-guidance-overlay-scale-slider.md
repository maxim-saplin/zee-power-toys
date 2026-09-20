---
status: done
labels: [hud, minimap]
created: 2026-09-20
satisfies: HUD · Minimap
blocked-by: [0055]
modules: [MinimapConfig, MinimapSettingsScreen, GuidanceOverlayView]
tier: T1
owner: zee-dev
---

# 0061 — GuidanceOverlayView overlay scale slider

## Block scope
Expose Zee HUD 2 `overlayScale` (already in `MinimapConfig` + native
`GuidanceOverlayView` layout) as a **DHU Minimap settings slider**. Persist via
existing SharedPrefs; live `setMinimapParam` / `_applyMinimapConfig` already
pushes `overlay_scale`.

## Zee HUD 2 parity
| Knob | Value |
|------|-------|
| Label | **Overlay scale** (EN) / Масштаб оверлея (RU) |
| Range | **0.25 – 1.0** (`coerceIn` on native + fromJson clamp) |
| Default | **0.5** |
| Value format | `0.5x` (phase0 `%.1fx`) |

Independent of map density (`contentScale`).

## Touches
- **Satisfies:** HUD · Minimap (0055 overlay stack)
- **Modules:** MinimapConfig, MinimapSettingsScreen, l10n EN/RU
- **ADRs:** ADR 0003 (config → native)

## Definition of Done
- [x] Slider in Minimap settings (`minimap-overlay-scale-slider`)
- [x] Prefs persist + clamp 0.25–1.0; default 0.5
- [x] EN+RU strings (Zee HUD 2 label)
- [x] Unit test: fromJson clamp
- [x] Issue + BACKLOG
- [ ] On-car: drag slider → guidance/ETA bars resize live (`adb install -r`)

## Reconciliation
Config + native path shipped with 0055; this Block is **UI-only** + clamp harden.

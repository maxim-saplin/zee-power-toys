---
status: done
labels: [hud, speedcam]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0060, 0058]
modules: [SpeedcamRadarWidget]
tier: T1
owner: zee-dev
---

# 0064 — Speedcam HUD blip colors (white danger / greenish others)

## Block scope
On HUD radar (**Default** + **Alien**), color the cam presence so the
**dangerous** contact stands out:

| Role | Color |
|------|-------|
| **Dangerous** cam (facing-relevant / current danger target, `highlight`) | **white** |
| **Other cams in range** (0060 scan set / approach radius, not the danger) | **greenish** phosphor |

Aligns with [0060](0060-speedcam-hud-sound-modes.md): HUD **Any** paints more
ahead cams; HUD **Dangerous** only facing-relevant ones — the mode’s selected
danger stays the white highlight.

## Touches
- **Modules:** `speedcam_radar_widget.dart` (`alienBlipFillColor`, Alien paint)
- **Prior:** [0060](0060-speedcam-hud-sound-modes.md), [0058](0058-hud-approach-cam-blip.md), [0042](0042-speedcam-alien-fidelity.md)

## Behaviour
- **Alien:** highlight blip fill + halo → white; dim scan blips → phosphor green.
- **Default:** approach readout already white (no multi-blip paint); unchanged
  beyond documenting the 0064 mapping.
- CRT chrome / rings / km readout stay phosphor (not blips).

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [x] Issue + BACKLOG
- [x] `alienBlipFillColor` — highlight white, other greenish
- [x] Alien painter uses fill helper for blips
- [x] Unit test for fill colors
- [x] 0055–0063 not touched
- [ ] On-car: `adb install -r` (parent) — white danger + greenish others under HUD Any

## Reconciliation
None vs PDM. Visual-only on tip `0044-publish-prep`; selection/gates remain 0060.

## Notes
Pre-0064 both highlight and other used phosphor greens (bright vs dim). This
Block only swaps highlight chroma to white.

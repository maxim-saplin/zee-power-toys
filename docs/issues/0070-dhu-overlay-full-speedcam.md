---
status: in-progress
labels: [speedcam, dhu, overlay]
created: 2026-09-21
satisfies: Full Speedcam UI on DHU as system overlay (not alert plate only)
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedcamSystemOverlay, Speedcam HUD]
priority: after-publish
filed-by: zee-qa
---

# 0070 — DHU overlay = full Speedcam UI (not plate only)

## Why
**0065** shipped a small always-on-top **text plate** over other apps.
Maxim’s ask: **one toggle** → real Speedcam UI on top of everything on the DHU
(over maps/nav), same idea as HUD — not a tiny alert strip.

## Gap vs 0065
| | 0065 (done) | 0070 (this) |
|---|---|---|
| What shows | Floating plate (distance / limit / “Speedcam”) | Full Speedcam UI (radar / map look as on HUD) |
| Where | DHU `TYPE_APPLICATION_OVERLAY` | Same overlay stack, richer content |
| Toggle | `dhuSystemOverlay` | Keep one switch; grow what it shows |

## Scope
- When overlay toggle ON + permission + approach: show **full Speedcam surface**
  in the system overlay (radar look matching HUD mode / Alien|Default as product picks).
- When OFF: nothing over other apps (HUD path unchanged).
- Emulator + DHU: same code path; emul proves overlay; car proves over YNavi.

## Out of scope
- Changing HUD Presentation / windshield path
- Icon / publish grind

## Implementation notes (2026-09-21 Minsk)

- Replaced 0065 TextView plate with a FlutterEngineGroup surface
  (`speedcamOverlayEntry` → [SpeedcamOverlayApp] → [SpeedcamRadarWidget]
  `dhuLarge`, Alien|Default from config).
- Same toggle `dhuSystemOverlay`; visibility still approach/demo via
  `_pushSpeedcamSystemOverlay` → native `update(visible)`.
- Hub fan-out: DHU `zee/hub` → HUD + overlay isolates.
- Version `1.0.0+6`. Evidence under `tmp/qa/` only.

## DoD
- [ ] Toggle ON → full Speedcam UI over launcher (T2) and over YNavi (T3)
- [ ] Toggle OFF → no overlay chrome
- [ ] Demo/approach drives the same overlay content
- [ ] QA cut after tip (`tmp/qa/` only)

---
status: done
labels: [hud, speedcam]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0035, 0038, 0058]
modules: [SpeedcamConfig, SpeedcamService, SpeedcamRadarWidget, SpeedcamAlertBinder]
tier: T1
owner: zee-dev
---

# 0060 — HUD + sound presence modes (Any / Dangerous / Off)

## Block scope
Independent prefs for **HUD radar/presence** and **alert sound**, each
`Any | Dangerous | Off`. Defaults: **HUD = Any**, **sound = Dangerous**.
Front-hemisphere scan for candidates. DHU Speedcam settings UI (EN+RU).

## Exact rules (tip-of-record `lib/services/speedcam.dart`)

**Scan set** (candidates):
- Host→cam relative bearing ≤ 90° (`isCamAheadOfTravel`) — fail-open if
  heading unknown
- Distance ≤ `approachRadiusM` (DHU range → service radius)

| Mode | Gate |
|------|------|
| **Dangerous** | Scan set ∩ `isCamRelevantForHost` (facing into our traffic; unknown facing/heading fail-open) |
| **Any** | Scan set **without** facing mute (includes same-direction / muted cams) |
| **Off** | That channel silent / no HUD paint |

Sound uses `resolvePresenceDanger(soundMode, …)` — Alien ping + Default sting
share the same selection. HUD paint uses `hudMode` (Alien fan dim blips follow
scan + mode; highlight tracks the mode’s danger). Pass-clear grace on the
service `danger` remains for **Dangerous** sound/HUD via `serviceDanger`.

### Clarify vs pre-0060
Pre-0060 `nearestDanger` = facing filter, **nearest anywhere**. 0060 adds
**ahead-only** to the default scan so behind cams are not candidates (pass-clear
still holds a just-passed Dangerous contact during grace).

## Prefs
- `SpeedcamConfig.hudMode` / `soundMode` (`SpeedcamPresenceMode`)
- Defaults: `hudMode=any`, `soundMode=dangerous`
- Migration: legacy `hudRadarEnabled`/`soundEnabled` bools → Off when false;
  true → Any (HUD) / Dangerous (sound)
- `toJson` still mirrors legacy bools for dumpState

## UI
DHU Speedcam → Radar: segmented **HUD radar** + **Alert sound**
(Any / Dangerous / Off). Volume slider unchanged.

## Definition of Done
- [x] Issue doc + BACKLOG with exact rules
- [x] Mode gate unit tests (scan / Any vs Dangerous / Off / prefs migrate)
- [x] Settings UI EN+RU
- [x] HUD + sound wired independently; 0055/0058/0059 intact
- [ ] On-car: HUD=Any shows muted-facing blip; sound=Dangerous stays quiet for it

## Reconciliation
None vs locked PDM spec. Overlay scale slider filed separately as [0061](0061-guidance-overlay-scale-slider.md).

---
status: done
labels: [hud, speedcam]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0035, 0034]
modules: [SpeedcamService, SpeedcamConfig, AudioSpeedcamAlert]
tier: T1
owner: zee-dev
---

# 0053 — Speedcam alerts: range / pass-clear / volume

## Block scope
Make DHU **alert presence range** actually drive proximity (`approachRadiusM`),
clear stale alerts ~3–5s after the host **passes** a cam, and add a persisted
**alert volume** for sting + Alien ping.

## Touches
- **Satisfies:** HUD · Speedcam
- **Modules:** `SpeedcamConfig.dhuRangeM` → `DefaultSpeedcamService.setApproachRadiusM`,
  `SpeedcamPassClearGate`, `AudioSpeedcamAlert.setVolume`, Speedcam settings
- **Prior:** [0034](0034-speedcam-dhu-radar-config.md) display range,
  [0035](0035-speedcam-alert-sound.md) sting arm

## Definition of Done
- [x] `dhuRangeM` prefs → config → `approachRadiusM` → `nearestDanger` /
      radar / alert binder (changing range changes when cams enter presence)
- [x] Unit/inject tests: distance inside vs outside the set range
- [x] Passed-by cam (behind / leaving via heading+bearing or distance trend)
      stays alerted ~4s, then clears (no forever “on course”)
- [x] DHU volume slider + persisted `soundVolume`; wired to sting + Alien ping;
      0 = silent; default ~0.85
- [x] Issue file `docs/issues/0053-speedcam-alerts-range-pass-volume.md`
- [ ] Runtime T1/T2 drive QA (pixels / ears)

## Reconciliation
Mac `machineId` unavailable in this agent; built on box checkout of
`0044-publish-prep` at tip `39151d4`+.

Root cause for range: `dhuRangeM` only drove DHU CRT *display* zoom while
`approachRadiusM` stayed hard-coded 500 m on the service + Alien painter.

## Notes
Do **not** start 0045. Follow-ups: 0054 (prefs survive reinstall), 0055
(Zee HUD 2 minimap info overlay).

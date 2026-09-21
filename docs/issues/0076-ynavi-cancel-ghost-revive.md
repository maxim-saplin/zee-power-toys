---
status: ready-for-agent
labels: [speedcam, ynavi, reliability]
created: 2026-09-21
satisfies: After Cancel/Guidance.stop, freeDriveRoute revives and ghost cams flow again while moving
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedCamBroadcaster / SpeedCamHook, ynavi-zee]
priority: now
filed-by: zee-pdm
---

# 0076 — Cancel → ghost: revive freeDriveRoute

## Why
Maxim DoD = cams while **roaming** (guidance or not). Joint cut FAIL: after cancel, `freeDriveRoute=null` and ghost SENT=0 despite `onStart` log. Doubles already PASS.

## Scope
- Real revive after `Guidance.stop()` / cancel — ghost `getEvents` size>0 + SPEEDCAM_DATA while moving.
- Keep Windshield closed; motion-backed only.
- Tips on `spike/ynavi-second-cam` then fold into 0071.

## Evidence
- FAIL: `tmp/qa/reliability-cancel-ghost2-qa/`
- Prior PASS pieces: route-on-Go, TTL kill, corridor leave, ZEE 0 doubles

## DoD
- [ ] ghost → Go → cancel → ghost2: SENT after cancel while moving
- [ ] 0 ZEE id doubles
- [ ] QA FINDINGS + PDM sign-off before calling reliable

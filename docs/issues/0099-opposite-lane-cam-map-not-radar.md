---
status: ready-for-agent
labels: [speedcam, osm, ynavi, radar, facing, collect]
created: 2026-09-23
satisfies: polish
blocked-by: []
modules: [SpeedcamService, SpeedcamPackStore, SpeedcamYnaviReceiver, speedcam_radar_widget, speedcam_pack_map_preview]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0038
related: [0081, 0092]
---

# 0099 — Opposite-lane cam on map but not grabbed / not on radar

## Block scope
Maxim 2026-09-23 (car drive): passed a camera watching the **other lane** at **53.906458, 27.449042**.

- Visible on the **pack map**
- **Not grabbed** (YNavi enrich / collect)
- **Not shown on Alien radar**

**Product intent (Maxim):** this class of cam **should be grabbed/stored** and **shown on the radar as non-dangerous** (visible, muted alert — not hidden). Facing must not gate collect; facing may mute *danger/alert* only (see 0038 + prior 0081 lesson).

## Investigate
1. Reproduce T2 near pin (motion + Enrich+Collect ON): is the cam in OSM pack? In YNavi bridge events? In store after pass?
2. Radar path: filtered out of blips entirely vs painted with muted / non-danger style? `camsForAlert` vs HUD `snap.cams` / presence (0092 taught HUD can bypass filters).
3. Facing / heading math at this pin: does “other lane” get treated as drop instead of mute?
4. Compare to 0081 pin `53.955491, 27.639103` (opposite-facing not stored) — same bug or new path?

## Definition of Done
- [ ] Root cause documented (collect vs radar vs both)
- [ ] Tip: cam at this pin is **stored** when Enrich+Collect ON and moving
- [ ] Tip: cam **appears on Alien radar** as **non-dangerous** (no sting / not treated as approach danger) when facing other lane
- [ ] QA FINDINGS + artifacts at **53.906458, 27.449042**; beta four-point; PDM ACCEPT after own check

## Notes
- Do not “fix” by hiding other-lane cams from the map.
- Prefer `ext.zee` / drive harness (0094) over OCR.

---
status: accepted
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
tip: 555aae9
accepted: 2026-09-23
evidence: tmp/qa/0099-cut-0633d85/
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
- [x] Root cause documented (collect vs radar vs both) — radar mute-over-drop; collect already unfiltered (`tmp/qa/0099-dev/ROOT_CAUSE.md`)
- [x] Tip: cam at this pin is **stored** when Enrich+Collect ON and moving — unit + T2 fixture store
- [x] Tip: cam **appears on Alien radar** as **non-dangerous** (no sting / not treated as approach danger) when facing other lane — `buildSpeedcamRadarBlips` dim blip (`555aae9`)
- [x] QA FINDINGS + artifacts at **53.906458, 27.449042**; beta four-point; PDM ACCEPT after own check — ACCEPT cut `0633d85` / fix `555aae9` (2026-09-23)

## Notes
- Do not “fix” by hiding other-lane cams from the map.
- Prefer `ext.zee` / drive harness (0094) over OCR.

## FINDINGS (dev tip)
**Radar:** Dangerous HUD blip loop dropped `!isCamRelevantForHost` cams (`continue`) and Alien hid the CRT with no highlight — opposite-lane pack cams vanished. **Fix:** mute-over-drop via `buildSpeedcamRadarBlips` (dim blip, no sting); Alien paints when `blips.isNotEmpty`.
**Collect:** `ingestYnaviEvent` already has no facing filter; unit test locks Enrich+Collect store at the pin.
Evidence: `tmp/qa/0099-dev/ROOT_CAUSE.md`, `test/services/speedcam_0099_opposite_lane_test.dart`.

## ACCEPT (PDM 2026-09-23)
Fix `555aae9` (cut on tip `0633d85`, 1.1.0+19). QA T2 PASS at pin 53.906458,27.449042 (`tmp/qa/0099-cut-0633d85/`); beta four-point PASS; PDM own check PASS. Mute-over-drop: opposite-lane OSM paints dim non-danger Alien blip (no sting); Enrich+Collect stores YNavi. Soft: roadside field re-drive — do not block Live +19.

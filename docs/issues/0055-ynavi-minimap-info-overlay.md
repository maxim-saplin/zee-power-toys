---
status: done
labels: [hud, minimap, ynavi]
created: 2026-09-20
satisfies: HUD · Minimap
blocked-by: [0054]
modules: [MinimapHost, HudRoot, NaviGuidanceLayer]
tier: T1
owner: zee-dev
---

# 0055 — YNavi minimap street/ETA (native chrome, not Flutter plate)

## Block scope
Restore street + ETA on the HUD minimap **from YNavi's own chrome**, not a
hand-built Flutter plate.

## Root cause (crop)
- YNavi MapActivity letterbox panels sit outside the cropped cluster square.
- Cluster TextureView **does** get map-pixel guidance chrome via
  `NaviGuidanceLayer.setManeuverStreetInfoVisible` (maneuver street info).
- That flag was experiment-gated (`projected/i0.B()` → often **false**) → no
  native street label on the minimap surface.

## FAIL (Flutter plate) — **REDIRECT / DELETED**
Earlier tip painted `MinimapGuidanceOverlay` from `GuidanceEvent` (DHU→HUD
relay). Maxim/PDM: **delete** that plate. Street/ETA must come from YNavi.

## Fix
1. **power-toys:** remove `MinimapGuidanceOverlay` + HudRoot paint path.
   Keep `GuidanceEvent` relay / `latestGuidanceProvider` for FL/diagnostics
   and `navActive` (0057) only.
2. **ynavi-zee:** force map-pixel street chrome on:
   - `projectedsession/b1.isManeuverStreetInfoVisible()` → always `true`
   - `bk1/s` layer create → `setManeuverStreetInfoVisible(true)`
   - Doc: `ynavi-zee/features/6.cluster_maneuver_street_info.md`

## Definition of Done
- [x] Flutter ETA/street plate deleted
- [x] YNavi native street-info toggle forced on (smali)
- [x] Issue + BACKLOG updated
- [ ] Runtime T2/T3: native street label visible on minimap during guidance
      (requires ynavi rebuild + `adb install -r` power-toys)

## Install note for parent
- Power-toys: `adb install -r` from tip on `0044-publish-prep`
- YNavi: rebuild Zeekr APK (`./build_zeekr.sh`) then `adb install -g -r -d`

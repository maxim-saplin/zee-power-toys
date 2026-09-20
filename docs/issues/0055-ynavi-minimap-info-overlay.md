---
status: done
labels: [hud, minimap, ynavi]
created: 2026-09-20
satisfies: HUD · Minimap
blocked-by: [0054]
modules: [MinimapHost, HudRoot, GuidanceEvent]
tier: T1
owner: zee-dev
---

# 0055 — Restore YNavi minimap info overlay (street, ETA)

## Block scope
Zee HUD 2 (`zee_hud_2`) showed street name + ETA on the HUD minimap. After
MinimapHost crop / letterbox / `contentScale`, that chrome disappeared. Audit
why; restore street + ETA for QA.

## Root cause
- YNavi paints guidance chrome (street, ETA panel, speed cluster) at the
  **letterboxed edges** of its MapActivity (`zeeapp_letterbox_*`, see
  `zee_hud_2/ynavi-zee/features/1.mapactivity_letterbox_padding.md` +
  `ISSUE_WITH_GUIDANCE_OFFSETS.md`).
- Power-toys `MinimapHost` composites a **cropped square** (phase0 SQUARE_LEFT
  + `minimapScale` buffer = viewport/scale). Edge chrome is outside that
  square → **dropped**.
- Trip data still flows: native `onTrip` → `GuidanceEvent{roadName,etaMin,distanceM}`
  but HudRoot previously declared guidance out of scope and painted nothing.

## Fix
- Flutter `MinimapGuidanceOverlay` under the minimap slot: street + distance +
  ETA from `latestGuidanceProvider` (stream of `MinimapHost.guidance`).
- Keeps emissive HUD rules (dim plate, phosphor text); no light cards.
- Does **not** start 0045.

## Definition of Done
- [x] Audit: crop/scale + letterbox clips native chrome; events still present
- [x] Overlay paints street + ETA when guidance events arrive
- [x] Unit/widget tests green
- [x] Issue doc `docs/issues/0055-ynavi-minimap-info-overlay.md`
- [ ] Runtime T2/T3 drive QA (pixels)

## Reconciliation
Product name: **Zee HUD 2** (`zee_hud_2`), not Z-Hat. Built on box after
0054 tip `33b3d6e`.

## Notes
Native YNavi ETA panel alignment quirks remain a mod concern; HUD now has an
honest Flutter fallback that survives crop.

## FAIL fix (T3 QA @ b3acb22)

**Symptom:** Overlay never paints on the windshield. `hudMain()` overrides
`minimapHostProvider` with a fresh `FakeMinimapHost`, so
`latestGuidanceProvider` never sees the DHU `zee/minimap/guidance`
EventChannel. Config / carSignals / speedcam already relay DHU→HUD; guidance
did not.

**Fix:**
- `pushGuidanceToHud` / `listenForRelay(onGuidance:)` on `zee/hub`
- `dhuMain`: `minimapHostRaw.guidance.listen(pushGuidanceToHud)`
- `hudMain`: named `FakeMinimapHost` + `onGuidance: emitGuidance`
- Native trip map prefers `step.cue` → `step.road` → `currentRoad`; ETA from
  `destinationTravelEstimates[0].remainingTimeSeconds` (Zee HUD 2 parity)

Car install: `adb install -r` only (0054 keep-data).

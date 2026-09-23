---
status: accepted
labels: [speedcam, map, ui, tap]
created: 2026-09-23
satisfies: polish
blocked-by: []
modules: [speedcam_pack_map_preview]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0093
tip: feb5c13
accepted: 2026-09-23
evidence: tmp/qa/0100-cut-0633d85/
---

# 0100 — Larger tappable speedcam map dots while scrolling / zoomed

## Block scope
Maxim 2026-09-23: cam dots on the DHU speedcam pack map are hard to tap while scrolling — **grow marker size** so cams stay tappable (esp. when zoomed / panning).

## Knob (main today)
`lib/widgets/speedcam_pack_map_preview.dart`:
- `dotR` shrinks with pack size (`2.0` / `2.5` / `3.5`)
- hit padding `(dotR * 2 + 14).clamp(22, 28)`

Raise **visible** and **hit** size so mid/high zoom and scroll still hit the marker; keep dense packs readable (may pair with 0101 clustering).

## Definition of Done
- [x] Tip: dots + hit targets clearly larger / easier to tap while scrolling on T2 — zoom-aware `camDotRadius` / `camHitExtent` (`feb5c13`)
- [x] 0093 metadata sheet still opens on tap
- [x] Dense packs do not become an unusable smear (cap, zoom-scaled size, or 0101 cluster) — density base + soft caps; clustering is 0101
- [x] QA FINDINGS + screenshots; beta four-point; PDM ACCEPT after own check — ACCEPT cut `0633d85` / fix `feb5c13` (2026-09-23)

## Notes
- Prefer zoom-aware sizing (larger when zoomed in) over a single huge constant.

## ACCEPT (PDM 2026-09-23)
Fix `feb5c13` (cut on tip `0633d85`, 1.1.0+19). QA T2 PASS (`tmp/qa/0100-cut-0633d85/`); beta four-point PASS; PDM own check PASS. Zoom-aware larger dots + hit targets; 0093 sheet still opens. Soft: myloc mid-zoom clusters deferred to 0101 note — do not block Live +19.

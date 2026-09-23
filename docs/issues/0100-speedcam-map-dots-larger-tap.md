---
status: ready-for-agent
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
- [ ] Tip: dots + hit targets clearly larger / easier to tap while scrolling on T2
- [ ] 0093 metadata sheet still opens on tap
- [ ] Dense packs do not become an unusable smear (cap, zoom-scaled size, or 0101 cluster)
- [ ] QA FINDINGS + screenshots; beta four-point; PDM ACCEPT after own check

## Notes
- Prefer zoom-aware sizing (larger when zoomed in) over a single huge constant.

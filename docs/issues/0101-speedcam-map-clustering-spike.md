---
status: ready-for-agent
labels: [speedcam, map, spike, cluster]
created: 2026-09-23
satisfies: polish
blocked-by: []
modules: [speedcam_pack_map_preview]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0100
---

# 0101 — Spike: speedcam map clustering (implement if reasonable)

## Block scope
Maxim 2026-09-23: **spike** map clustering for the speedcam pack preview; **implement** if cost/UX look good (pairs with 0100 larger dots).

Today: hard downsample `kMaxMarkers = 2000` + tiny dots when dense — lose cams and tapability.

## Spike questions
1. flutter_map cluster plugin / custom grid cluster fit our stack without heavy deps?
2. Zoom-out: cluster bubbles with count; zoom-in: expand to individuals (and 0100 sizes)
3. Tap: cluster → zoom/expand; single → 0093 detail sheet
4. Perf on T2 with full ~300 km pack

## Definition of Done
- [ ] Spike note in issue Reconciliation (or `docs/knowledge/`) — go / no-go + why
- [ ] If go: ship clustering on tip with T2 evidence (zoom-out cluster, zoom-in individuals, tap paths)
- [ ] If no-go: document cheaper alternative (zoom-scaled dots only / smarter downsample) and close spike
- [ ] QA FINDINGS when implemented; beta four-point; PDM ACCEPT after own check

## Notes
- Do not block 0100 on this spike — larger dots can land first.
- Do not block 0099 (facing/collect) on map UX.

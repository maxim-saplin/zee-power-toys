---
status: accepted
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
tip: 0633d85
accepted: 2026-09-23
evidence: tmp/qa/0101-cut-0633d85/
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
- [x] Spike note in issue Reconciliation (or `docs/knowledge/`) — go / no-go + why
- [x] If go: ship clustering on tip with T2 evidence (zoom-out cluster, zoom-in individuals, tap paths) — `0633d85`
- [x] If no-go: document cheaper alternative (zoom-scaled dots only / smarter downsample) and close spike — N/A (GO shipped; cheaper alt noted in Reconciliation)
- [x] QA FINDINGS when implemented; beta four-point; PDM ACCEPT after own check — ACCEPT `0633d85` (2026-09-23)

## Notes
- Do not block 0100 on this spike — larger dots can land first.
- Do not block 0099 (facing/collect) on map UX.

## Reconciliation

### Spike verdict: **GO** (2026-09-23)

Custom **zoom-scaled geographic grid** in `speedcam_pack_map_preview.dart` — **no new pubspec dep**.

| Question | Answer |
|----------|--------|
| 1. Plugin vs custom? | **Custom grid.** `flutter_map_marker_cluster` fits flutter_map v8 but pulls popup/animation weight we do not need on DHU. Existing downsample already used grid buckets — extend that with zoom cell size + count bubbles. |
| 2. Zoom-out / zoom-in? | Cell degrees ≈ `(360 / (256·2^z)) · 52px`. Low z → cluster bubbles with count; high z → individuals using **0100** `camDotRadius` / `camHitExtent`. |
| 3. Tap paths? | Cluster → `fitCamera` on member bounds (maxZoom 16). Single → **0093** `showSpeedcamPointDetailSheet` (unchanged). |
| 4. Perf / full ~300 km? | O(n) bucket + viewport filter after map ready (pad 20%) so high zoom does not build thousands of off-screen Markers. Soft `kMaxMarkers` widens radius rather than dropping cams. Unit stress: 3000 cams cluster ≪ 500 ms on host. |

**Cheaper alternative (if reverted):** keep 0100 zoom-scaled dots + smarter downsample only — readable but still loses cams / tap targets when dense.

Tip: `tip/0101-speedcam-map-clustering` (see commit). Caption always shows full pack count (no “showing N” drop).

## ACCEPT (PDM 2026-09-23)
Tip `0633d85` (1.1.0+19). Spike **GO**: custom zoom-grid clustering (no plugin). QA T2 PASS (`tmp/qa/0101-cut-0633d85/`); beta four-point PASS; PDM own check PASS. Dense 130 → count bubbles; cluster tap → individuals; single → 0093 sheet. Soft: myloc z≈13 on dense still clustered — ACCEPT, no zoom-threshold tweak. Soft C1 Live SHARED_USER on Tablet — do not block Live +19.

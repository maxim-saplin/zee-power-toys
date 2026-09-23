---
status: open
labels: [speedcam, qa, harness, hardening, osm, ynavi]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [SpeedcamService, SpeedcamPackStore, ext.zee.speedcam, feedback_loop]
tier: T2
owner: zee-qa
priority: now
filed-by: zee-pdm
matrix: docs/qa/0096-hardening-matrix.md
---

# 0096 — Speedcam hardening matrix (T2 exhaustive)

## Block scope
Maxim 2026-09-23 (via beta): not another pin prove — a **proper T2 use-case matrix** covering OSM / YNavi / merge+enrich / lane mute vs true SPEED / dedupe / aging / alert modes. Exhaustive harness cut. Live stays **1.1.0+11** until PDM says bump.

Canonical matrix: `docs/qa/0096-hardening-matrix.md` (tip `ed09b08`, A–F). Holes from 0092: **A2/A6** (true YNavi SPEED must still flow with mute OFF).

## Locked DoD
- [ ] Matrix on tip (`docs/qa/0096-hardening-matrix.md`) — already tipped
- [x] **Fixture RPC in-scope this slice** (see below) landed before A2/A6 claim PASS — tip this wave (`action=fixture` / `speedcam-fixture` CLI)
- [ ] Unit gate green (`speedcam_*` especially 0088 / ynavi_enrich / ynavi_merge / 0072_74 / aging)
- [ ] Every **A/B/C/D/E** row on T2 is **PASS** or **SKIP+reason** per skip policy below
- [ ] **F1** PASS (53.907996,27.424118 OFF→ON→OFF)
- [ ] **F2** PASS only if Maxim supplies coords; else SKIP+reason
- [ ] Evidence `tmp/qa/0096-cut-<sha>/` with per-case artifacts; harness only / keepalive; no OCR
- [ ] Beta four-point; PDM ACCEPT after own check
- Soft: matrix replay recipe (script or zee_run) — nice-to-have, not a HOLD

## Fixture RPC (IN SCOPE this slice)
```
ext.zee.speedcam action=fixture
  source=ynavi|osm|osm+ynavi
  camType=SPEED|LANE
  eventId=...
  lat=... lon=... maxspeed=60
  hostLat=... hostLon=... speedKmh=50 headingDeg=...
→ dump-state / snapshot.danger asserts
```
Also cover controlled `eventId` inject for **B** rows (same tip or follow tip same wave). Without fixture, A2/A6 cannot honestly PASS on T2.

## Skip policy (locked)
1. **Prefer tip over SKIP** — if a row needs a harness knob we don't have, tip the fixture/config first in this slice.
2. **Honest SKIP only** when the product surface does not exist yet (document which key/RPC missing). SKIP text = one line reason + owner follow-up.
3. **Never SKIP A2/A6** after fixture lands — those are the 0092 holes; FAIL if mute kills true SPEED.
4. **F2** → SKIP until Maxim gives field coords (ask once in FINDINGS if still missing).
5. **C rows** → try set-config / packInstall aged timestamps first; if knobs absent after check → SKIP+reason (not silent pass).
6. **D2** may reuse prior 0060 recipes; cite evidence path or re-run — no ghost PASS from memory.
7. Unit green ≠ T2 PASS. Units gate only.

## Sequence
1. zee-dev: tip `action=fixture` (+ B inject if needed) on tip
2. zee-qa: drive full matrix FINDINGS per row
3. zee-dev-beta: early-review matrix/fixture; parallel A2/A6; four-point after QA
4. PDM: ACCEPT; Live stay +11 unless separate ship call

## Owners
- zee-pdm: this issue / DoD / skip policy / ACCEPT
- zee-dev: fixture RPC + harness gaps
- zee-qa: T2 matrix FINDINGS
- zee-dev-beta: early review + parallel A2/A6 + four-point

---
status: ready-for-agent
labels: [speedcam, osm, ynavi, enrich, false-alarm]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [SpeedcamPackStore, SpeedcamService, YNavi enrich]
tier: T2
owner: zee-dev
priority: after-0087
filed-by: zee-pdm
---

# 0090 — YNavi direction enrich for OSM cams (no heading → false alerts)

## Problem (Maxim 2026-09-23)
Some OSM speedcams have **no direction**. Without heading, facing rules cannot apply and Maxim gets **false dangerous alerts**. YNavi cam feed often has direction — investigate whether we can **reliably** take direction from a matching YNavi cam and attach it to the OSM cam (enrich the OSM record / alert path), not invent headings.

## Investigate
- Match OSM ↔ YNavi by lat/lon proximity (existing merge radius?)
- When OSM lacks direction and YNavi match has a clear heading/facing, copy that into the merged / OSM-facing path used by `camsForAlert`
- Do **not** overwrite a good OSM direction with a bad YNavi one
- Do **not** invent direction when YNavi also lacks it
- Interaction with 0088: lane filter must stay pure-YNavi; OSM typing must not get silenced

## Product bar
Optional or automatic enrich is fine once reliability is proven — prefer **automatic when match is confident** (document confidence rule). Default must reduce false alerts, not create new ones.

## Definition of Done
- [ ] Spike FINDINGS: can we get reliable direction from YNavi for undirected OSM cams? Match criteria + failure modes
- [ ] If yes: tip that enriches OSM (or osm+ynavi alert path) with YNavi direction only when OSM direction missing and YNavi heading known
- [ ] T2 evidence: undirected OSM cam that previously false-alerted stops alerting when heading says opposite; still alerts when facing
- [ ] Unit tests for enrich / no-overwrite / no-invent
- [ ] PDM ACCEPT after own double-check of evidence (stringent — no tip-only LGTM)

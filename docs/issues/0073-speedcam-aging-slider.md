---
status: ready-for-agent
labels: [speedcam, ynavi, policy]
created: 2026-09-21
satisfies: Aging/renewal for cam points — default 7 days, user slider
tier: T2
owner: zee-dev-beta
blocked-by: [0071]
modules: [SpeedcamPackStore, Speedcam settings]
priority: now
filed-by: zee-pdm
---

# 0073 — Aging: 7-day default + slider

## Why
YNavi (and store) points must age out; Maxim default **7 days**, adjustable.

## Scope
- Persist `lastSeen` / harvest time per point (esp. `source=ynavi`; apply consistently so OSM doesn’t rot wrongly — document rule).
- **Default TTL = 7 days.** Slider in Speedcam setup changes default (sensible range e.g. 1–30 days).
- Expired points drop from store + map + alerts; renewal on re-ingest resets age.
- EN+RU labels.

## DoD
- [ ] Fresh install: 7d default visible
- [ ] Slider persists; aging drops stale points
- [ ] Re-seen YNavi cam renews age
- [ ] QA + PDM sign-off

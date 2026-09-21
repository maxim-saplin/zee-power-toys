---
status: ready-for-agent
labels: [speedcam, ynavi, settings]
created: 2026-09-21
satisfies: Independent on/off for YNavi collecting and YNavi alerting
tier: T2
owner: zee-dev-beta
blocked-by: [0071]
modules: [SpeedcamConfig, SpeedcamYnaviReceiver, SpeedcamAlertBinder, settings UI]
priority: now
filed-by: zee-pdm
---

# 0074 — YNavi collect on/off + alert on/off

## Why
Maxim: separate control for **collecting** vs **alerting** from YNavi.

## Scope
- Two prefs (under Speedcam setup, gated by 0071 master enrich if useful):
  - **Collect YNavi** — ingest into store when ON
  - **Alert YNavi** — sound/HUD/DHU treat YNavi points when ON
- Sensible defaults: with enrich ON → collect ON, alert ON (or match existing HUD/sound modes — document).
- Collect OFF + alert ON must not alert on ghost YNavi if not in store (or only OSM) — no half-broken path.
- EN+RU.

## DoD
- [ ] Collect OFF → no new YNavi points
- [ ] Alert OFF → YNavi points silent even if collected
- [ ] Both combinations QA’d
- [ ] PDM sign-off

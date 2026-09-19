---
status: in-progress
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: []
modules: [SpeedcamService, ConfigStore, Feedback Loop]
tier: T1
owner: zee-dev
---

# 0030 — SpeedcamService port + Fake + FL inject

Parent: [0029](0029-speedcam-osm-epic.md). **No YNavi.**

## Block scope
Add `SpeedcamService` port (ADR 0003 style): stream of nearby cams + most-dangerous alert; commands enable/disable. `FakeSpeedcam` for T1 with embedded sample cams. `ext.zee` inject / setConfig to simulate host motion toward a cam (team adapts — no car needed).

## Definition of Done
- [x] Port + Fake + Riverpod injection
- [x] FL can inject position / approach so danger flips inside 500 m
- [x] Unit tests for geometry helpers if extracted
- [ ] Runtime-confirmed on **T1** — dumpState/readViewModel shows cams + danger

## Notes
Pack download can stub empty; Fake owns sample data until 0031 lands. Prefer shipping 0030 first if pack HTTP is slow.

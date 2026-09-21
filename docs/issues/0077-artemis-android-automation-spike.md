---
status: ready-for-agent
labels: [qa, automation, spike]
created: 2026-09-21
satisfies: Decide keep/kill google/artemis vs current adb + UIAutomator + GPS scripting
tier: T2
owner: zee-dev-beta
blocked-by: []
modules: [tmp/qa harness, emulator ops]
priority: parallel
filed-by: zee-pdm
---

# 0077 — Spike: google/artemis vs our Android automation

## Why
Maxim: research whether Artemis is worthwhile for Zee emu/DHU automation, or keep adb/UIAutomator/GPS scripts. Decide **keep or drop** with evidence — not a rewrite for sport.

## Context (current stack)
- `adb` + `uiautomator` + gRPC/setGps on `Tablet_Android_12L` (`emulator-5554`)
- Pain: ANR leftovers, emu flaps, brittle UI taps, long idle harnesses, MBP lid disconnects
- **Nokia N1 out of scope** (other project)

## Spike questions (answer all)
1. What is Artemis today (repo/status/license) — usable on our host?
2. Can it drive our emu: launch YNavi/toys, tap Go/Cancel, assert logs/UI?
3. Vs current harness: setup cost, flakiness, agent-friendliness, offline?
4. Fit for Speedcam reliability cuts (0076-class) without rewriting everything?
5. **Verdict:** adopt / trial-only / **kill** — one sentence + evidence paths.

## Out of scope
- Replacing live 0071–0076 product work
- Production car automation day-1

## DoD
- [ ] Short FINDINGS in `tmp/qa/artemis-spike/` (or `docs/spikes/`)
- [ ] Plain-English keep/kill for Maxim
- [ ] PDM sign-off on verdict

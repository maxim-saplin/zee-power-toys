# 0043 — Quality sweep before publish prep

## Status
in-progress (A+B+E tipped; D N/A shameful; C=QA)

## Goal
Raise the bar so features are production-ready on T1+T2 before staging publish changesets (Maxim reviews / go later). **No publish green.**

## Ordered lanes (do in order; tip each)

### A — Freeze tip + Speedcam credit
- Tip of record: `956d6b8` Speedcam (0041/0042) + `f4c1204` chore if still HEAD
- Credit Speedcam in README + About (Maxim)

### B — Deps + analyzer
- `flutter pub outdated` / bump safe deps; `dart analyze` clean; macOS/desktop deps already moved at `f4c1204`

### C — Regression matrix (T1 then T2)
@zee-qa owns cuts; @zee-dev fixes FAILs same day.
Must cover at least:
1. Home / two-column DHU
2. HUD: blinkers, battery looks, minimap enable
3. Speedcam: Default idle empty; Demo Alien/Default; Stop idle; multi-cam bright/dim on HUD; sound on
4. Install screen opens (links may still be stub until publish prep)
5. Config persist cold boot (radarLook etc.)

### D — Tech debt / follow-ups
- Kill obvious TODOs/FIXMEs that block production honesty
- Deferred BACKLOG items: only fix if they are shameful for publish; else leave listed

### E — Test coverage
- Add/extend tests for Speedcam relay multi-cam, radarLook cold-boot, Demo/Stop
- No coverage theater — target regressions that burned us (relay Map type, pushConfig)

### F — Docs honesty
- CONTEXT/REQUIREMENTS/issue statuses match reality
- Agent-oriented README stays until publish lane rewrites landing (0044)

## DoD
- [x] A Credit + About tipped
- [x] B deps+analyze tipped
- [ ] C Regression matrix (QA)
- [x] D Tech debt — no shameful TODO/FIXME in lib/ (left BACKLOG)
- [x] E Coverage — About + radarLook nested + Demo; facing-mute approach tests fixed
- [ ] F Docs honesty
- [ ] A–F tipped or explicitly N/A with reason
- [ ] T1+T2 regression matrix green (or FAIL→fix→PASS logged)
- [ ] @zee-pdm ACCEPT on 0043 → unlock publish prep (0044)

## Out of scope
- Commit/push/publish to GH (Maxim only after go)
- Platform-signed release binary upload (publish prep)

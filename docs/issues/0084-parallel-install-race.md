---
status: ready-for-agent
labels: [install, race]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [InstallScreen, AppSelfUpdate]
tier: T2
---

# 0084 — Parallel toys Update + YNavi Install race

## Block scope
Car session 2026-09-22: starting toys self-update and YNavi install together aborted the toys update; after YNavi progress finished the app restarted as if toys (not YNavi) had installed.

## Definition of Done
- [ ] Reproduce on T2: start Update + Install YNavi overlapping
- [ ] Either serialize (disable second action while one in flight) or isolate installers so both complete correctly
- [ ] Runtime evidence on T2; no silent restart attributing wrong package

## Notes
Diagnose NOW / fix on T2. Car observed while Maxim driving.

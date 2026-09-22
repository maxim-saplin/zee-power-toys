---
status: ready-for-agent
labels: [install, ux]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [InstallScreen, AppSelfUpdate]
tier: T2
---

# 0086 — Install progress bar goes backwards after download

## Block scope
After download, progress drops a few % before install — misleading. Prefer spinner / indeterminate for install phase; verify on T2.

## Definition of Done
- [ ] Download phase can stay determinate; install phase must not look like progress reversing
- [ ] T2 recording / screenshots of Update flow

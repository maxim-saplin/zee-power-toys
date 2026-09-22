---
status: tipped
labels: [install, ux]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [InstallScreen, AppSelfUpdate, InstallerController]
tier: T2
tip: PENDING
---

# 0086 — Install progress bar goes backwards after download

## Block scope
After download, progress drops a few % before install — misleading. Prefer spinner / indeterminate for install phase; verify on T2.

## FINDINGS — root cause
Download progress is `downloaded/total` and reaches **~1.0**. Immediately after, Kotlin emitted:

```text
{phase: "installing", fraction: 0.8}
```

Both `_SelfUpdateCard` and `_InstallCard` bound `LinearProgressIndicator.value` to `fraction` whenever the job was busy, so the bar jumped from ~100% → 80% at the phase change. Not a multiplex/0084 cross-talk bug — a phase-mapped fraction that is smaller than end-of-download. PackageInstaller has no byte-level progress, so 0.8 was a placeholder, not real install %.

## Tip (`PENDING`)
- Dart: `installProgressBarValue` — determinate for downloading/done; **indeterminate (`null`) for installing** (and failed).
- Kotlin: emit `installing` at **1.0** (download-complete) instead of 0.8 so any determinate consumer stays monotonic.
- FakeInstaller installing fraction → 1.0; widget + unit tests cover legacy installing@0.8 does not reverse the bar.

## Definition of Done
- [x] Download phase stays determinate; install phase does not look like progress reversing — tipped
- [ ] T2 recording / screenshots of Update flow (PDM QA)
- [ ] PDM ACCEPT after double-check

## QA recipe (T2)
1. Install screen → tap **Install** on Launcher or YNavi (or **Update** if a newer release is available).
2. Watch the card progress bar through download → install → done.
3. Expect: bar fills 0→100% during **Downloading…**; on **Installing…** it becomes an **indeterminate** (sliding) bar — never drops a few %; on **Done** it sits at full.
4. Optional parallel with 0084: Update + YNavi together — each card still monotonic / install-spinner independently.
5. logcat `ZEE/Installer`: `phase=downloading fraction=…` up to ~1.0, then `phase=installing fraction=1.0`, then `phase=done fraction=1.0`.

---
status: done
labels: [fix, hygiene, docs, tests]
created: 2026-06-12
satisfies: No dead weight + tests-at-the-behaviour-boundary + docs-reconciled (Principle 6 / DoD)
blocked-by: []
modules: [repo, docs, tests]
tier: static + T1
---

# 0024 — Repo hygiene + docs reconcile + scale test (QA fix round, Batch C)

## Block scope
Final worst-first QA fix batch: dead-weight removal, the missing pure-logic test, and
the docs-reconciliation backlog surfaced by QA5 (and the doc-drift nits from QA3).

## What this Block delivered
- **[QA5-1/2] Dead weight untracked** — `git rm --cached flutter_01.log` and the 2.2 MB
  `zSupport-1.3.5-release.apk`; `.gitignore` now covers `flutter_*.log` + `*.apk`. (`.metadata`
  is intentionally kept — it is a conventionally-tracked Flutter project file, not drift.)
- **[QA5-3] `dhuSmartScale` test** — `test/widgets/dhu_scaled_layout_test.dart`: 8 pure-logic
  cases (automotive threshold, clamp ceiling, dpr gate, NaN/∞/≤0 guards) + 2 widget cases
  (scales on the 2560-wide automotive surface, passes through on a phone). +10 tests → **209**.
- **[QA5-14] Release-safe logging** — `native_car_signals.dart` raw `print()` → `debugPrint`
  (dropped the now-redundant `meta` import).
- **[QA3-4] Comment accuracy** — `agent_extensions` `usbWritable` comment now reflects the
  optimistic-true-until-failed-write reality.
- **Docs reconciled** — README "16 Blocks" → 23; `CONTEXT.md` service glossary gains
  `Installer` / `SystemConfig` / `UsbMode`; `feedback-loop-contract.md` `dhu-toggle` path
  fixed (→ `hud_settings_screen.dart`); `SKILL.md` `ext.zee.minimap` tier corrected
  (T1 Fake / T2-T3 native, not "T2 DHU").
- **[QA5-9 + harness] Tracked deferrals** — BACKLOG gains a "Deferred hardening" list
  (installer dedup test, per-tier VM-URI files, dev FGS auto-start, behaviour-boundary test
  cleanups, conventions-doc dep snapshot) so non-blocking polish stays visible.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] `flutter analyze` clean; `flutter test` = **209** green.
- [x] Dead-weight binaries no longer tracked; `.gitignore` prevents recurrence.
- [x] Docs reconciled in-commit (README / CONTEXT / contract / SKILL / BACKLOG).
- [x] Trunk green — no regression.

## Notes
Closes the QA fix round (Batches A/B/C = Blocks 0022/0023/0024). Remaining items are the
explicitly-tracked, non-blocking "Deferred hardening" list in the BACKLOG; nothing gates T3.

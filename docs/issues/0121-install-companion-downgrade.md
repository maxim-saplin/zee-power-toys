---
status: tip-ready
tip: 7f3f836
labels: [install, companion, downgrade, ynavi]
created: 2026-09-28
satisfies: Install APKs screen — uninstall/replace newer companion so older can install (YNavi 27 after 30)
tier: T2
owner: zee-dev
blocked-by: []
modules: [InstallApksScreen, companion install]
priority: soon
filed-by: zee-pdm
related: [0103, 0097]
---

# 0121 — Install APKs: allow companion downgrade

## Product (Maxim 2026-09-28)

Install screen must let the user get an **older** companion APK onto the device after a **newer** one is already installed.

- Example: YNavi **v27** after **v30** is installed — today the install attempt appears to do **nothing**.
- Need an explicit path: uninstall / delete newer companion, or forced replace, with clear user-visible feedback if blocked.

## DoD

- [x] From Install APKs, user can remove or replace a newer companion (YNavi minimum; same pattern for other companions on that screen).
- [x] Installing older after newer succeeds (or fails with a clear message — never silent no-op).
- [ ] T2 dens320 proof: v30 → Replace → OK → auto-install Release v27 (or clear Failed) — @zee-qa re-cut.
- [x] Tip to `origin/main`.

## Soft / out of scope

- Signing / SHARED_USER platform quirks beyond what the screen can surface (soft).
- Car T3 unless T2 cannot prove the package swap.
- Live bump — **hold 1.1.0+27** until Maxim GO.
- PackageInstaller UI “Done” on session commit before STATUS_SUCCESS / package present (soft / pre-existing).

## DEV tip (2026-09-28 Europe/Minsk)

- tipAhead → **Replace with older** → confirm → `REQUEST_DELETE_PACKAGES` + `ACTION_DELETE`.
- **Fix (post QA FAIL e63ae16):** translucent UninstallerActivity on dens320 Tablet may never deliver `paused` — resume alone left stale tipAhead after DELETE_SUCCEEDED. Now: poll while awaiting (missing → `_startInstall`), treat `hidden` like pause, soft-resume without pause (install if missing; deadline → clear Failed). Never silent stale tipAhead.
- Evidence FAIL: `tmp/qa/0121-cut-e63ae16/FINDINGS.md`
- Live: **1.1.0+27** hold.
- Who-next: **@zee-qa** re-cut Replace→OK→auto v27 (or Failed).

---
status: tip-ready
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

- [ ] From Install APKs, user can remove or replace a newer companion (YNavi minimum; same pattern for other companions on that screen).
- [ ] Installing older after newer succeeds (or fails with a clear message — never silent no-op).
- [ ] T2 dens320 proof: v30 present → action → v27 install path works.
- [ ] Tip to `origin/main`.

## Soft / out of scope

- Signing / SHARED_USER platform quirks beyond what the screen can surface.
- Car T3 unless T2 cannot prove the package swap.

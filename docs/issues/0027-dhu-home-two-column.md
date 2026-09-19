---
status: done
labels: [app-shell, dhu, install]
created: 2026-09-19
satisfies: App-shell · DHU navigation / first-run
blocked-by: []
modules: [Installer, ConfigStore, Settings home]
tier: T1
---

# 0027 — DHU home: two-column landing (welcome + sections)

## Block scope
Replace the current single-list **Settings hub** (`SettingsHomeScreen`) with a **two-column home**:

- **Welcome column:** short product intro / welcome, **verification of installed APKs** (our app companions: modded Launcher + YNavi mod — installed vs missing), and **Download / Install** actions when missing (reuse Installer + `install_targets.dart`).
- **Sections column:** the existing individual items (HUD, Minimap, Diagnostics, Language, Install, USB/ADB, …) as tiles; tap opens the **full-screen** screen as today.

First paint should feel like a product home, not a buried settings list.

## Touches
- **Satisfies:** REQUIREMENTS App-shell (Install from GitHub) + DHU UX first impression
- **Modules:** Settings home shell, Installer (status probe), l10n
- **ADRs:** 0001 (Flutter UI), 0003 (Installer port)

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Two-column home on DHU (T1 macOS / Linux or T2) — welcome+status | section tiles
- [x] Installed-APK status honest (installed / missing / unknown) for Launcher + YNavi
- [x] Missing → Install/Download buttons drive existing Installer path
- [x] Section tiles still open full-screen routes (HUD, Minimap, …)
- [x] Localized EN/RU; agent keys for welcome actions + nav tiles
- [ ] Runtime-confirmed — artifact: screenshot of home + dumpState/install status

## Notes
Customer ask 2026-09-19 (Maxim). Does not replace Install screen; home surfaces status + shortcuts. Publish/GH link polish can land later (Publish & release backlog).

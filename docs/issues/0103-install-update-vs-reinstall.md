---
status: ready-for-agent
labels: [install, self-update, companions, ux]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [install_screen, app_self_update, package_status, install_targets]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: [0069]
---

# 0103 — Install: Update vs Reinstall + YNavi/Launcher version align

## Block scope
Maxim 2026-09-25 (with 0102 arm): on Install / Check-update UX:

1. Button says **Update** when a **newer** version is available.
2. Button says **Reinstall** when the **same** version is already installed (re-fetch / re-sideload still allowed).
3. Align **“new version available”** semantics for **YNavi** and **Launcher** companion cards with toys self-update (same compare honesty).

## Current gap (toys tip ≥ `cd9b421`)
- Self-update (`_SelfUpdateCard` / `AppSelfUpdate`): action is `updateInstallButton` = **“Update now”** only when `AppUpdateAvailable` (remote code **>** installed). Up-to-date shows status text only — **no Reinstall**.
- Companions (`_InstallCard`): always `installButtonLabel` = **“Install / Update”** — **no** installed versionCode compare vs Release asset; Launcher/YNavi “newer available” not shown like self-update.
- `PackageStatus` only returns installed/missing/unknown — not versionCode vs Release.

## Product rules
| Installed vs Release | Button | Status copy |
|----------------------|--------|-------------|
| missing / unknown | Install (or keep Install / Update if unknown) | honest |
| installed code **<** Release | **Update** | “Update available: …” (aligned EN/RU) |
| installed code **==** Release | **Reinstall** | up-to-date / same build |
| installed code **>** Release (lab tip ahead) | soft: Reinstall Release or note tip ahead — document in Reconciliation | |

Apply to: toys self-update card **and** Launcher + YNavi (+ OS7) companion cards on the same Install screen. YNavi/Launcher **repos** stay Releases-only unless a real in-app UI exists there (toys Install is the UX surface).

## Definition of Done
- [ ] Self-update: **Update** when newer; **Reinstall** when same Latest installed (downloads+installs same tag asset)
- [ ] Companion cards (Launcher, YNavi, YNavi OS7): probe installed package versionCode vs Release asset; same Update / Reinstall labels + “new version available” status aligned with self-update
- [ ] EN + RU l10n; units for compare helper
- [ ] T2 evidence on Tablet dens 320: screenshots / dumpApp keys for Update vs Reinstall states (can fake PackageStatus / override installedCode in tests)
- [ ] Beta four-point; PDM ACCEPT after own check

## Notes
- Ship after or parallel with **0102** (0102 is P0 false-alert; 0103 is Install UX). Prefer one tip if cheap; else 0102 first.
- Do not invent YNavi/Launcher in-app updaters — align via **toys Install** companions.

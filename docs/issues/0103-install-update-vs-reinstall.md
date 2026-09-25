---
status: accepted
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
tip: bb45870
accepted: 2026-09-25
evidence: tmp/qa/0103-cut-bb45870/
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
- [x] Self-update: **Update** when newer; **Reinstall** when same Latest installed (downloads+installs same tag asset) — `bb45870`
- [x] Companion cards (Launcher, YNavi, YNavi OS7): probe installed package versionCode vs Release asset; same Update / Reinstall labels + “new version available” status aligned with self-update
- [x] EN + RU l10n; units for compare helper (`release_compare_test`, `app_self_update_test`)
- [x] Widget/unit coverage + T2 dens-320 screenshots — `tmp/qa/0103-cut-bb45870/`
- [x] Beta four-point; PDM ACCEPT after own check — ACCEPT `bb45870` (2026-09-25)

## Reconciliation
**2026-09-25 tip `bb45870`:** Install UX Update vs Reinstall on self-update + companion cards.
- Compare helper: `compareVersionCodes` / `releaseActionFor` (`lib/services/release_compare.dart`).
- Self-update: latest published APK → `AppUpdateAvailable` / `AppUpdateReinstall` / `AppUpdateTipAhead` (asset retained for == and tip-ahead). EN button **Update** (was “Update now”); **Reinstall** / RU **Переустановить**.
- Companions: `PackageStatus.probe` returns versionCode; native `zee/packages` `probe` method. Pins: YNavi `738798690`, Launcher `305019` (`launcher-670` tag is GH label).
- Home companions unchanged (Install-when-missing only) — optional follow-up.
- Soft: installed **>** Release → tip-ahead status + Reinstall Release asset.
- Live version **not** bumped. No in-app updaters in ynavi/launcher repos.

## ACCEPT (PDM 2026-09-25)
Tip `bb45870` (1.1.0+19, Live **not** bumped). QA T2 PASS (`tmp/qa/0103-cut-bb45870/`); PDM own check PASS. Self on Latest `1.1.0+19` → **Reinstall**; YNavi tip-ahead of pin → **Reinstall** + tip-ahead status; Launcher missing → **Install**. Soft: **home** still install-when-missing only; Launcher pin `305019` vs tag `launcher-670` — do not block.

## Notes
- Shipped after **0102** tip `62720d0`.
- Do not invent YNavi/Launcher in-app updaters — align via **toys Install** companions.

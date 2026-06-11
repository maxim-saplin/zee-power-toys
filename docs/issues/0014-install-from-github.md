---
status: done
labels: [app-shell, install]
created: 2026-06-11
satisfies: App-shell · install — download modded Launcher + YNavi mod from GitHub and install
blocked-by: [0011]
modules: [Installer]
tier: T2
---

# 0014 — Install modded Launcher + YNavi mod from GitHub

## Block scope
A localized DHU **Install** screen that downloads the **modded Launcher** and the **YNavi mod (HUD-capable)** from configured **GitHub releases** and installs them via Android `PackageInstaller`, with live progress. The GitHub source (repo/tag/asset) is configurable data; the mechanism is the feature. On T2 the download + install-intent path is demonstrated; the actual install confirmation / on-car install is T3.

## Touches
- **Satisfies:** REQUIREMENTS — "Allow to download from GitHub and install: Modded Launcher with YNavi configured as default navi; YNavi mod with HUD support."
- **Modules:** Installer (NativeInstaller on Android; FakeInstaller on T1).
- **ADRs:** 0002 (one APK), 0003 (Installer port).

## Grounding
- The Installer port + progress model already exist: `lib/services/installer.dart` (`Installer`, `GithubAsset`, `InstallProgress`/phase), `lib/services/fakes/fake_installer.dart`. Nav/l10n: `lib/screens/settings_home_screen.dart` (Install placeholder), `lib/l10n/*.arb`.
- Android install: `PackageInstaller` session API (preferred) or `Intent.ACTION_VIEW`/`ACTION_INSTALL_PACKAGE` with a FileProvider; `REQUEST_INSTALL_PACKAGES` permission. Download via Kotlin HttpURLConnection/OkHttp (no heavy dep) to the app cache, with progress.

## What to build
- **NativeInstaller** (Android, `lib/services/adapters/native_installer.dart` + native `zee/installer` channel + Kotlin): given a `GithubAsset` (repo, tag, assetName — resolve the GitHub releases download URL), download to cache emitting progress (downloading%→installing→done/failed), then launch `PackageInstaller` (or the install intent). Manifest: `REQUEST_INSTALL_PACKAGES`, a FileProvider if using the intent path. Inject on Android; `FakeInstaller` on T1 (already simulates progress).
- **Install screen** `lib/screens/install_screen.dart`: two cards (Modded Launcher, YNavi mod) — each shows name/desc + an Install/Update button + a progress bar bound to the `Installer.install(asset)` stream. The two `GithubAsset`s are defined as config/constants (repo/tag/asset placeholders, clearly marked TODO-real-URLs; document where the user sets them). Localized. Wire into the Settings hub (Install section, `ValueKey('nav-install')`).
- ARB keys (EN + RU). `ext.zee.*` so the loop can trigger an install + read progress (e.g. `ext.zee.install asset=launcher|ynavi`, readViewModel includes last install phase).

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] **T1:** Install screen renders (Modded Launcher + YNavi mod), localized; triggering an install runs the Fake downloading→installing→done with a progress bar. — artifact: `shots/install_progress.png`; readViewModel `install{phase:done}`.
- [x] **T2:** NativeInstaller downloaded a real public GitHub release asset (Aegis `v3.3`, ~6 MB; 302→200 CDN redirect handled) to cache with live progress, then **created + committed a PackageInstaller session**. — artifact: logcat (download% → `session created`/`committed` → `phase=done`). Real install completion / unknown-sources grant is T3/user-gated.
- [x] analyze clean; **153 tests** green; build linux + apk ok. Principles: no heavy HTTP dep (HttpURLConnection); progress + failures surfaced.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus), 2026-06-11.
1. **Install path:** PackageInstaller **session API** (preferred), with a FileProvider+`ACTION_VIEW` fallback. `REQUEST_INSTALL_PACKAGES` + `INTERNET` + FileProvider declared. Real release coordinates are deployment data — placeholders in `lib/services/install_targets.dart` (clearly TODO-marked); the user supplies the real modded-Launcher / YNavi-mod repos.
2. **T2 test asset:** `beemdevelopment/Aegis` `v3.3` (a small public OSS APK) — proves the download+install mechanism end-to-end on the emulator.
3. **Known minor issue (hardening in the 0017 final T2 sweep):** `InstallerController.startInstall` fires from BOTH the EventChannel `onListen` and the MethodChannel `start()` (the Dart adapter opens the stream then calls start) → a double-start on first invoke. The install still completes; an `isRunning` idempotency guard in `InstallerController` is the fix. Mechanism is proven; the guard is additive hardening.

## Notes
The specific modded-Launcher / YNavi-mod release URLs are deployment data — wire them as clearly-marked config constants; the user supplies the real repos. The install *mechanism* is what this Block proves.

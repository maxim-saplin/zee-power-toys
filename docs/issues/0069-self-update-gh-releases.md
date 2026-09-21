---
status: in-progress
labels: [publish, install]
created: 2026-09-20
satisfies: Auto-update Zee Power Toys from public GitHub Releases
modules: [Installer, AppSelfUpdate]
tier: T2
---

# 0069 — Self-update from public GitHub Releases

## Scope
In-app check + download/install of a newer **zee-power-toys** APK from public
Releases on `maxim-saplin/zee-power-toys`, reusing the Installer / PackageInstaller
path (0014).

## Contract
- **Tag:** `1.0.0+N` or `v1.0.0+N` (N = Android versionCode / pubspec `+BUILD`)
- **Asset (first match):** `zee-power-toys.apk`, else `app-release.apk`, else any `.apk`
- **API:** anonymous `GET /repos/maxim-saplin/zee-power-toys/releases` (skip draft/prerelease)
- **Compare:** remote code > `appVersionCode` in `lib/app_version.dart` (keep in sync with pubspec)
- **Install:** existing `Installer.install(GithubAsset)` with `directUrl` from `browser_download_url`

## UI
Install screen: self-update card (Check / Update). About shows `appVersionFull`.

## Release pipeline note
`release.yml` stays Maxim-gated. When publishing, upload the platform-signed APK
as `zee-power-toys.apk` (or `app-release.apk`) on a non-draft tag matching the contract.

## DoD
- [x] Unit tests for parse + check (mock HTTP)
- [ ] T2: check against a real public release (or staged tag)
- [ ] analyze + full test suite green

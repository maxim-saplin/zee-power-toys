---
status: ready-for-agent
labels: [install, update, companions, ynavi]
created: 2026-09-29
satisfies: Install reports the latest published YNavi artifact against the installed package
tier: T2
owner: zee-dev
blocked-by: []
modules: [Install screen, PackageStatus, YNavi release metadata]
priority: now
filed-by: zee-pdm
related: [0103, 0115, 0121, 0122]
---

# 0126 — Toys detects new YNavi releases

## Block scope

Make the Install screen identify the current published artifact for each YNavi channel and compare it with the installed package. Publishing a YNavi mod update must not require a Toys release just to refresh a compiled version pin.

## Current gap

- Toys reads the installed package versionCode from Android PackageManager.
- The offered versionCodes, release tags, and asset names are compiled into `install_targets.dart`.
- A rebuilt YNavi mod can have the same upstream versionCode as the installed APK. In that case the current comparison says Reinstall, even if the GitHub asset has changed.
- GitHub tag and asset name identify a download; they are not a reliable installed-build identity.

## Product rules

1. Keep v27 stable as the default channel and v30 as the explicit beta channel.
2. Resolve each channel's current public release and matching APK asset. Stable must ignore drafts and prereleases; beta must select its designated prerelease.
3. Define a machine-readable artifact identity that represents the APK build, including mod-only rebuilds with unchanged upstream versionCode. Publish and read that identity across YNavi Releases and Toys; do not infer it from the tag or filename.
4. Use the artifact identity for Update versus Reinstall. Keep Android versionCode available for install compatibility and the existing Replace older path.
5. Fail soft on network, API, or metadata errors. Do not report a stale pin as the latest release.
6. Do not change Toys self-update or Launcher behavior in this Block.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] YNavi release publishing exposes the machine-readable artifact identity for each supported channel.
- [ ] Toys resolves the stable and beta release metadata and compares it with the installed YNavi artifact identity.
- [ ] Tests cover stable versus prerelease selection, newer/same/older identity, missing asset/metadata, and network failure.
- [ ] T2 Install-screen verification proves a new YNavi release is detected without publishing a new Toys APK; v27 default and v30 beta behavior remain correct.

## Reconciliation

None.

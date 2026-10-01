---
status: in-progress
labels: [release, versioning, install, update, ynavi]
created: 2026-09-29
satisfies: YNavi mod builds have versioned releases and Toys detects them without a Toys release
tier: T2
owner: zee-dev
blocked-by: []
modules: [YNavi release pipeline, APK version metadata, Toys Install screen]
priority: now
filed-by: zee-pdm
related: [0091, 0103, 0115, 0121, 0122]
---

# 0126 — YNavi build-numbered releases and Toys update detection

## Block scope

Give every published YNavi mod build its own incremented APK version/build and immutable GitHub Release. Make Toys discover the latest build for each supported channel and compare it with the installed APK without requiring a Toys release.

## Current gap

- The v27 `src/apktool.yml` and v30 build metadata use only upstream versionName/versionCode (`27.0.2` / `738798690`; `30.8.1` / `739652660`). A mod-only rebuild keeps those values.
- The v27 release workflow is manually dispatched and overwrites assets on the supplied tag. The v30 Zee recut uses a fixed prerelease tag and a local `tmp/v30` build. Neither has a per-mod-build release identity.
- Toys has compiled YNavi release tags, asset names, and versionCode pins. It cannot tell that a rebuilt APK is newer when upstream versionCode is unchanged.

## Version and release contract

1. Keep upstream app version and mod build distinct. Put both in the APK identity, for example `27.0.2+1` and `30.8.1+1` (`versionName`), and in a unique tag such as `ynavi-zeekr-v27.0.2+1` or `ynavi-zeekr-v30.8.1+1`.
2. Increment the mod build for every newly published rebuild of that upstream line, including mod-only smali/resource changes. Existing unnumbered releases are migration baselines; do not rewrite them. Never reuse a published tag or overwrite its assets.
3. Increment Android `versionCode` for each build using a documented, collision-safe mapping. Preserve install ordering: v27 must remain older than v30 until a newer upstream base changes that ordering. Do not use a simple global counter that could make an older v27 APK appear newer than v30.
4. Create one Release per version/build. v27 remains the stable/latest channel; v30 remains an explicit prerelease/beta. All variants in one release share the same version/build identity.
5. Generate a machine-readable release manifest with channel, upstream version, mod build, APK versionName/versionCode, asset filenames, and SHA-256 hashes. Toys must use this manifest, not infer builds from a Git tag, filename, or APK download.
6. Normal publishing is tag-triggered CI from versioned, reproducible inputs. CI validates tag/manifest/APK metadata agreement and creates the Release without overwriting prior builds. Keep local ignored `tmp/v30` output out of the release source of truth.

## Toys behavior

- On Install-screen open, resolve the latest stable v27 release and the designated v30 prerelease from public GitHub Releases.
- Compare the installed package identity with the selected channel's manifest: newer published build means **Update**; same build means **Reinstall**.
- Continue to use Android versionCode to protect install/downgrade ordering, including the existing **Replace older** path when moving from v30 back to v27.
- Fail soft on network, API, or manifest errors. Do not claim a pinned or stale build is the latest.
- Do not change Toys self-update or Launcher behavior in this Block.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] Each YNavi release has an incremented mod build in APK metadata and a unique, immutable version/build tag.
- [ ] Android versionCode mapping is documented and tested for incrementing within a line and correct v27/v30 install ordering.
- [ ] CI builds each supported release from versioned inputs, validates metadata, generates the manifest, and publishes assets without clobbering prior releases.
- [ ] Toys discovers stable and beta release manifests and compares installed versus published build identities without a Toys APK bump.
- [ ] Tests cover build increments, release/channel selection, Update/Reinstall/Replace older, malformed or missing metadata/assets, and network failure.
- [ ] T2 verifies v27 and v30 installs, same-version mod-build update detection, and v30-to-v27 replacement behavior.

## Reconciliation

- **2026-10-01** — YNavi half merged to `ynavi-zee` main (`9354e06`, PR #5). Toys half: Install open resolves stable v27 + beta v30 via `ynavi-release-manifest.json` on public Releases; compile pins are install fallback only (no “latest” claim when discovery fails). T2 still open.

## Toys implementation notes

- Contract/schema: `maxim-saplin/ynavi-zee` @ main — `releases/ynavi-release-manifest.schema.json`, `releases/lines.json`, `docs/0126-release-version-contract.md`.
- Discovery: `lib/services/ynavi_release_discovery.dart`; wired on Install open (`ynaviReleaseDiscovererProvider`).
- Compare uses manifest `versionCode` (Update / Reinstall / Replace older unchanged).

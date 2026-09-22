---
status: tipped
labels: [ynavi, publish]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [InstallScreen, ynavi-zee]
tier: T2
tip: 8eca1e0
---

# 0087 — YNavi release label should show upstream major+build

## Block scope
"v12" is misleading. Label Zeekr + Deepal builds with upstream YNavi major (e.g. v27)+build, not internal v12 counter.

## FINDINGS — root cause
Release tag / asset filenames used an **internal mod counter** (`ynavi-zeekr-v12`, `zeekr_v12_*.apk`, `deepal_v12.apk`). The real product bar on the base APK is apktool `versionName` **27.0.2** / `versionCode` **738798690**. Install cards and README Release tables echoed that `v12` name, so Deepal+Zeekr looked like a different major than Yandex Navi About.

## Tip (`8eca1e0`)
- `install_targets.dart`: `kYnaviUpstreamVersionName` / `kYnaviUpstreamLabel` / `kYnaviUpstreamVersionBuild` (`27.0.2+738798690`); Release tag `ynavi-zeekr-v27.0.2`; assets `zeekr_v27.0.2_{margined,os7_nomargin}.apk`.
- Install card titles (EN/RU) include `v27.0.2`.
- README EN/RU Release cards + publish notes match.
- **ynavi-zee**: workflow defaults + README / NOTES rename Deepal+Zeekr assets/tag the same way (GH Release cut is PDM — not part of this tip).

## Definition of Done
- [x] UI + Release naming show upstream YNavi version for both variants — tipped (code/docs; PDM cuts GH Release)
- [x] Docs/README cards match — tipped
- [ ] PDM creates/uploads Release `ynavi-zeekr-v27.0.2` assets (Deepal + both Zeekr)
- [ ] PDM ACCEPT after double-check

## QA recipe (T2 / docs)
1. Open Install — YNavi cards titled with **v27.0.2** (not v12).
2. README Release table: tag `ynavi-zeekr-v27.0.2` / `zeekr_v27.0.2_*.apk`.
3. After PDM Release exists: Install → YNavi download URL resolves under that tag (no 404).
4. Optional: installed YNavi About / `dumpsys package` versionName matches **27.0.2**.
5. Unit: `flutter test test/services/install_targets_upstream_label_test.dart`.

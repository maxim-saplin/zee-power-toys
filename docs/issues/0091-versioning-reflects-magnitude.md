---
status: ready-for-agent
labels: [release, versioning, process]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [pubspec.yaml, CHANGELOG.md, docs/publish/ci-release.md]
tier: docs
owner: zee-pdm
priority: release-gate
filed-by: zee-pdm
---

# 0091 — Versioning must reflect change magnitude

## Problem (Maxim 2026-09-23)
Build numbers alone (`1.0.0+5` … `+10`) do **not** show the magnitude of changes. User-facing CRT parity, lane-cam filter, USB cold-open, install races all shipped while remaining on **1.0.0**.

CHANGELOG already states: bump `+BUILD` every tip/APK; bump **MAJOR.MINOR.PATCH** for user-facing releases — practice ignored.

## Policy (locked)
`MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml` (PackageInfo / self-update / About):

| Bump | When |
|------|------|
| **MAJOR** | Breaking install / incompatible with prior data or car contract |
| **MINOR** | User-visible features or meaningful behavior change (new toggles, CRT parity, alert policy) |
| **PATCH** | Bugfix / polish only, no new capability |
| **+BUILD** | Every tip or release APK; must be strictly increasing (Android `versionCode`) |

## This release train
Queue since 1.0.0+10 includes 0083 LARGE CRT, 0088 lane filter, 0085 USB cold-open, 0084/86 install UX, 0087 labels, possibly 0090 direction enrich → **MINOR**.

**Ship as `1.1.0+N`** (N > 10, e.g. `1.1.0+11`). Do **not** ship another `1.0.0+11`.

## DoD
- [ ] `docs/publish/ci-release.md` + CHANGELOG policy restated with examples
- [ ] Next public release tag is `1.1.0+N` (or higher MINOR if 0090 lands as feature)
- [ ] Tips between releases may stay on same MINOR.PATCH with +BUILD only; **release** always considers magnitude
- [ ] PDM gates release version bump before tag

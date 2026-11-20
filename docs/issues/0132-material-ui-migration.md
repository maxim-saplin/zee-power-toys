---
status: open
labels: [tech-debt, flutter, ci]
created: 2026-11-20
satisfies: CI/releases stay green on current stable Flutter
blocked-by: []
modules: [all Dart imports, .github/workflows]
tier: T1
owner: zee-dev
priority: soon
filed-by: zee-dev
related: [0131]
---

# 0132 — Migrate material.dart → material_ui (Flutter 3.48 deprecation)

## Block scope

Flutter stable 3.48+ deprecates `package:flutter/material.dart` in favor of
`package:material_ui/material_ui.dart` (deprecated after v3.47.0-0.0.pre).
`flutter analyze` then reports ~63 repo-wide infos and CI treats them as
fatal — the 1.2.6+41 release run failed on analyze before building.

## Interim state

Both workflows pin `flutter-version: 3.47.8` (the proven local toolchain),
which keeps CI and releases green. The pin must not outlive this migration.

## Definition of Done

- [ ] All `material.dart` imports migrated to `material_ui` (lib + test).
- [ ] `flutter analyze` clean on Flutter ≥ 3.48.
- [ ] Full test suite green on Flutter ≥ 3.48.
- [ ] Workflow pins removed or re-pinned to the new verified version.
- [ ] Local toolchains upgraded to match before unpinning.

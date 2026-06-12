---
status: done
labels: [foundation, ui, app-shell, minimap, install]
created: 2026-06-12
satisfies: DHU UI quality · HUD · Minimap · App-shell · install
blocked-by: []
modules: [Theme/DHU UI, MinimapHost, Installer, Feedback Loop docs]
tier: T2
---

# 0020 — Leftovers: DHU low-DPI scale-up + minimap-host wiring + real install coords + doc reconcile

## Block scope
Close out the remaining high-value "leftovers" that survived Blocks 0017–0019:

1. **DHU low-DPI UI scale-up** — 2560×1600 @ 160 dpi renders at dpr≈1.0; the
   UI canvas is 2560 logical px wide, making controls tiny.  Port the
   `ScaledLayout` pattern (from `nothingness` reference): auto-scale (3.0 for
   the DHU) wraps the MaterialApp builder; the RepaintBoundary stays inside so
   `ext.zee.shot` captures the scaled image.  Tests pass because scale≈1.0 at
   test sizes (pass-through).

2. **MinimapConfig → MinimapHost wiring** — `setConfig` updated minimap config
   but nothing called `MinimapHost.enable()` or `setBounds()`.  Wire it: on
   every config change call `enable(mm.enabled)` + `setBounds(bounds)` from the
   preset-to-fraction mapping (added to `MinimapConfig.presetFractions` +
   `resolvedFracs`); fires once on startup from persisted config.

3. **Real install coordinates (LFS raw URL)** — replace placeholder
   `zeepowertoys/modded-*` repos with real LFS-tracked APKs in
   `maxim-saplin/ynavi-zee` and `maxim-saplin/zee_hud_2`.  Switch download URL
   from GitHub releases to LFS raw content CDN.  Rename `GithubAsset` fields
   from `tag`/`assetName` to `branch`/`path` (semantic clarification); add
   `downloadUrl` getter.

4. **`nav-hud` ValueKey doc reconcile** — `.agents`/`.claude` skill docs
   claimed the HUD settings tile had no ValueKey; it has had `nav-hud` since
   Block 0017.  Fixed in both mirrors (duplication noted for QA).

5. **Stray TODO sweep** — all `TODO` comments in shipped `lib/` resolved.
   Remaining `android/app/build.gradle.kts` release-signing placeholder is a
   known on-car item (commented, not a compile issue).

## Touches
- **Satisfies:** DHU UI quality (scale-up), HUD Minimap (host wiring), App-shell
  install (real coordinates + URL), docs (skill / contract reconcile).
- **Modules:** DhuScaledLayout (new), MinimapHost, MinimapConfig, Installer,
  GithubAsset, InstallerController (Kotlin).
- **ADRs:** 0001 (HUD isolation), 0002 (one artifact), 0004 (Feedback Loop
  drivability), 0007 (delivery discipline).

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Runtime-confirmed on **T2** — artifact: `shots/redo/t2-dhu-scaled.png`
      showing scaled-up premium DHU UI (3.0× on 2560×1600).
- [x] Minimap preset wiring verified via `read-view-model --surface dhu` and/or
      `set-config minimapEnabled=true minimapPreset=large` logcat evidence.
- [x] `flutter analyze` clean; `flutter test` ≥ 199 green.
- [x] Single coherent commit, trunk green.

## Reconciliation
- `.agents/skills/drive-zee-app/SKILL.md` line 189: "HUD settings tile has no
  ValueKey" → corrected to list `nav-hud`.  Same fix applied to `.claude/` mirror.
- `docs/feedback-loop-contract.md`: `ext.zee.install` params updated from
  `repo tag asset` → `repo branch path`.
- `GithubAsset` model: `tag`/`assetName` renamed to `branch`/`path` + new
  `downloadUrl` getter.  `InstallerController.kt` updated accordingly.
- Note: `.agents/skills/` and `.claude/skills/` are duplicate skill trees
  (same content, two root dirs) — flagged here for QA/consolidation but not
  deleted (per instructions).
- `android/app/build.gradle.kts` release-signing TODO: left intentionally —
  release signing requires an on-car certificate that is a deployment concern,
  not a code concern.

## Notes
- DHU scale 2560×1600@dpr1.0: `isLikelyAutomotive(2560, 1.0)` = true
  (dpr<2.0 ∧ width≥1600); scale = (2560/800).clamp(1.0, 3.0) = **3.0**.
- MinimapHost bounds use calibrated 1024×576 HUD display constants (Zeekr S2,
  T3); T2 emulator secondary display may differ in size, but the wiring and
  the enable/setBounds calls are what matters for T2 verification.
- 8 new tests added (minimap preset fractions); total test count: 199.

---
status: done
labels: [fix, ui, drivability, localization]
created: 2026-06-12
satisfies: Feedback-Loop drivability (Principle 3) + DHU UX quality (Principle 1) + EN/RU localization
blocked-by: []
modules: [agent_extensions, DHU UI, SystemConfig, l10n]
tier: T1+T2
---

# 0023 — Drivability fix + DHU UX + localization (QA fix round, Batch B)

## Block scope
Second worst-first QA fix batch (after [0022](0022-hud-optics-lifecycle-hardening.md)):
the Dart drivability **blocker**, the DHU UI/UX **majors**, the off-car
`setLanguage` false-positive, and localization gaps surfaced by the five QA passes.

## What this Block delivered

### Drivability (Principle 3 — the Feedback Loop is a first-class user)
- **[QA3-1 BLOCKER] `tapByKey` silently no-op on invisible `GestureDetector` keys.**
  `lib/debug/agent_extensions.dart` — the first-tier subtree walk now passes
  `includeSelf: true`, so the matched element's own `onTap` is invoked directly and
  success is only reported when a callback actually fired. Keys `minimap-preset-*`,
  `blinker-shape-*`, `minimap-theme-*`, `usb-*` now change state. Runtime-confirmed
  (T1): `tap minimap-preset-large` → preset `balanced → large`.
- **[QA3-2 MAJOR] `inject` allowed HUD CarSignals to diverge.** Inject is now
  registered **only on the DHU** surface (HUD `CarSignals` are relay-driven), so the
  two isolates can't diverge. Docs reconciled (`feedback-loop-contract.md`, SKILL.md).

### DHU UX (Principle 1 — simplicity, excellent defaults, no bloat)
- **[QA2-1 MAJOR] HUD Settings preview hid all controls.** `hud_settings_screen.dart`
  now uses a sticky split — a height-capped `HudPreview` above an `Expanded` scrolling
  control list — so the live preview stays visible **while** editing.
  ([QA2-3] `HudPreview` max-height cap folded in.)
- **[QA2-2 MAJOR] USB/ADB write-switch was buried in read-only Diagnostics.** Extracted
  to a dedicated `lib/screens/usb_adb_screen.dart` reached from a new settings-hub tile
  (`ValueKey('nav-usb')`); Diagnostics keeps only a **read-only** live USB-mode value.
- **[QA2-4 MINOR] Minimap "Advanced" hid the preset chooser.** Presets stay visible;
  Advanced is a separate expander.
- **[QA2-5 MINOR] Settings home half-empty.** Added a contextual status footer.

### Language correctness + localization
- **[QA3-3 / QA2-6 MAJOR] `setLanguage scope=system|cluster` falsely returned `ok:true`
  off-car.** `FakeSystemConfig` reports unsupported off-car; `SystemConfigController.kt`
  no longer claims success for a non-persistent emulator locale change; the Language
  screen disables the System/Cluster pickers off-car. Runtime-confirmed (T1):
  `setLanguage scope=system` → `{ok:false, reason:"unsupported-on-device"}`.
- **[QA2-7 NIT]** HUD preview slot labels (`GUIDANCE`/`MINIMAP`) localized
  (`hudSlotGuidance`/`hudSlotMinimap`, EN+RU, key parity kept).
- **[QA2-8 NIT]** RU `languageSystem` clarified ("По умолчанию (системное)").

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] `flutter analyze` clean; **199 tests** green (HudRoot tests reconciled to the
      localized slot labels by providing l10n delegates in the test wrapper).
- [x] Drivability blocker runtime-confirmed (T1): `tapByKey` now changes state.
- [x] `setLanguage` off-car runtime-confirmed (T1): `unsupported-on-device`.
- [x] DHU UX changes runtime-confirmed (T1) — minimap presets visible + premium layout;
      USB tile wired; Diagnostics read-only.
- [x] Docs reconciled in-commit (contract.md inject=dhu; SKILL.md inject=dhu + `nav-usb`
      + `blinker-shape-smiley` + usb keys).
- [x] Trunk green — no regression to prior Blocks.

## Reconciliation
- `docs/feedback-loop-contract.md` + `.agents/skills/drive-zee-app/SKILL.md` — `inject`
  surface corrected to `dhu` (was contradictory `both`/`dhu`); key inventory extended.
- `test/widgets/hud_root_test.dart` — wrapper now supplies `AppLocalizations` delegates
  (HudRoot's preview slot labels are now localized).

## Notes
Delivered as a QA fix round; the on-car HUD-optics blockers were handled in 0022.
Remaining QA items (repo hygiene, README/CONTEXT, dhuSmartScale test, harness vm-uri,
stale-doc batch) are tracked for the next batch.

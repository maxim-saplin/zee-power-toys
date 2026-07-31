---
status: done
labels: [hud, dx]
created: 2026-07-29
satisfies: HUD · preview (extends 0006/0007/0008)
blocked-by: []
modules: [ConfigStore, hud, car_signals]
tier: T2                        # runtime-confirmed in the Android emulator
---

# 0026 — Split Config Preview (always-visible demo) from Developer Simulate (live signal injection)

## Block scope

`HudPreview` (the grey-glass box on the HUD Settings screen, Block 0006/0007/0008) renders
the real `HudRoot`/`BlinkerWidget`/`BatteryWidget` subtree wired to the *live* CarSignals
providers. That is correct for anti-drift (ADR 0001), but it means the preview goes blank
whenever there is no live blinker/charging signal — which is most of the time a developer or
user is sitting in Settings tinkering with shape/size/position, since nothing is actually
driving the car. Confirmed directly: on T2, injecting `blinker=left` lights the preview;
setting `blinker=off` (or simply not injecting anything, the default state) makes it go dark,
even though the user hasn't changed any config — the preview is not showing "what you'll get,"
it's showing "whether a signal happens to be active right now."

This Block splits that one overloaded screen into two purpose-built surfaces:

1. **Config Preview** (fix the existing `HudPreview`) — CarSignal-driven slots (blinker,
   charging) are forced to a fixed, always-on demo state scoped to the preview subtree only,
   so editing shape/size/position is always visible. Config providers (`blinkerConfigProvider`,
   `batteryConfigProvider`, `safeAreaProvider`, ...) are untouched and keep reacting live —
   only the *signal* providers are overridden, and only inside `HudPreview`'s own
   `ProviderScope`, so the real HUD surface (a separate engine/isolate) is unaffected.
2. **Developer Simulate** (new, debug-gated screen/section) — in-app buttons/sliders that
   emit real synthetic `CarSignalEvent`s (blinker left/right/hazard/off, charging on/off + kW,
   battery level, speed) through the actual unforced provider chain — the in-app equivalent of
   `ext.zee.inject` / the T2 ADB broadcast — so a developer can watch genuine live
   animation/cadence/transitions (e.g. the 450ms blink timer, hazard-both-sides, the
   show-while-charging panel appearing/disappearing) without shelling out to `adb` or the
   VM-service.

Also retire `hudBoxOn` (`ConfigStore` field + the "Debug HUD box" toggle in
`hud_settings_screen.dart`): per Block 0006's own reconciliation note it already gates nothing
in `hud_root.dart` — it's a Block 0006 skeleton leftover. Once the Config Preview always shows
content, the flag has no remaining purpose and should be deleted outright, not left as a fake
control.

## Touches
- **Satisfies:** REQUIREMENTS.md:30-31 — "UI preview for HUD, target accurate presentation... of
  what might be expected in HUD" — read as *representative demo*, not literal live-telemetry
  mirroring (the ambiguity this Block resolves).
- **Modules:** `lib/widgets/hud_preview.dart`, `lib/hud/blinker_widget.dart` (no change expected —
  consumes `blinkerProvider` as-is), `lib/hud/battery_widget.dart` (same), `lib/providers/car_signals.dart`,
  `lib/services/config_store.dart` (remove `hudBoxOn`), `lib/screens/hud_settings_screen.dart`
  (remove the debug toggle row, add the Developer Simulate entry point).
- **ADRs:** 0001 (Flutter-first, anti-drift — the override must stay scoped to `HudPreview`'s own
  `ProviderScope`, never touching the root container `configStoreProvider`/`carSignalsProvider`
  inject via `ProviderScope.overrides` at app root, `lib/providers/services.dart:13-19`), 0003.

## What to build
- `HudPreview`: wrap the `HudRoot` child in a nested `ProviderScope` overriding
  `blinkerProvider` → `BlinkerState.hazard` (shows both sides at once — checks left/right
  symmetry in one glance), `chargingProvider` → `true`, `chargeKwProvider` → a plausible sample,
  `batteryPctProvider` / `batteryTempCProvider` → plausible samples. Everything else HudRoot
  reads is left un-overridden so it falls through to the root container (Riverpod provider
  scoping) — config edits made on the same screen must keep updating the preview live.
- Delete `hudBoxOn` end-to-end: `ConfigStore`/`AppConfig` field, `hudBoxOnProvider`, the
  `SettingsToggleRow`/`Switch` in `hud_settings_screen.dart`, the `l10n.debugHudBox` string,
  the `ext.zee.setConfig hudBoxOn=` param in `agent_extensions.dart`, and the `dhu-toggle`
  `ValueKey`. Check `docs/feedback-loop-contract.md` and this skill's docs for stale references.
- New **Developer Simulate** screen (or a collapsible debug-only section reachable from HUD
  Settings) — gated so it never ships in a release build (mirror however `kDebugMode` is already
  checked elsewhere in this app, e.g. wherever extensions are registered). Controls: blinker
  (left/right/hazard/off), charging (on/off + kW slider), battery (level + temp sliders), speed.
  Each control calls into the same `CarSignals` service the ADB broadcast / `ext.zee.inject`
  already targets, so it drives the *real* `blinkerProvider` etc. — no override involved. Put it
  next to (or as a toggleable overlay on) the real HUD surface view so behavior is watchable
  live, not just read from `dumpState`.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically — **all runtime-confirmed
in the Android emulator (T2)**, both surfaces visible, not just asserted from `dumpState`:
- [x] Config Preview always shows a lit blinker (both sides) and full charging stats on the HUD
  Settings screen **with no CarSignal injected at all** (fresh `zee_run.py up --tier t2`,
  nothing broadcast) — artifact: `/tmp/dhu-config-preview-nosignal.png` (hazard dots + 72%/7kW,
  zero signals injected this session).
- [x] Changing blinker shape/size/position or battery size while on that screen still updates
  the Config Preview live (existing 0007/0008 behavior preserved) — artifact:
  `/tmp/dhu-config-preview-arrows.png` (shape flipped dots→arrows via `tap blinker-shape-arrows`,
  preview updated immediately, hazard hint + battery demo unchanged).
- [x] The real HUD surface (`feedback_loop.py shot --surface hud`) is **unaffected** by the
  Config Preview's forced demo state when no signal is injected — i.e. it stays blank — proving
  the override is correctly scoped and does not leak into the production render path. Artifact:
  `/tmp/hud-nosignal.png` (empty battery shell, no blinker, taken right after the two Config
  Preview screenshots above with nothing ever injected).
- [x] Developer Simulate screen: triggering blinker/charging/battery/speed controls in-app
  (not via adb) is reflected on the real HUD surface — artifact: `/tmp/dhu-simulate-left.png` +
  `/tmp/hud-simulate-left.png` (tapped `simulate-blinker-left` via `tapByKey`; both the Simulate
  screen's own live preview and the real HUD surface show the left mark).
- [x] `hudBoxOn` fully removed — `grep -r hudBoxOn lib/` returns nothing; `flutter analyze` clean;
  no test references the removed field/toggle (7 test files updated).
- [x] Localization: `sectionSimulate(Subtitle)`, `simulateTitle`, `simulateDescription`,
  `simulateBlinkerLabel`, `simulateOff/Left/Right/Hazard`, `simulateChargingLabel`,
  `simulateChargeKwLabel`, `simulateBatteryLabel`, `simulateBatteryTempLabel`, `simulateSpeedLabel`
  added to both `app_en.arb`/`app_ru.arb`; `debugHudBox` removed from both.

## Reconciliation
1. **`Override` (Riverpod) is not part of the public export surface** in `riverpod`/`flutter_riverpod`/`hooks_riverpod` 3.3.2 — cannot be named as an explicit type. `_demoSignalOverrides` in `hud_preview.dart` is an untyped list literal instead (mirrors the existing pattern already used for the root `ProviderScope.overrides` in `main.dart`).
2. **Developer Simulate needed a small native addition**, not just Dart: on T2/T3, `NativeCarSignals` only *listens* for events (native → Dart); there was no Dart → native path to inject synthetically in-app (only the external ADB `SimulateReceiver` broadcast). Added a `"simulate"` case to `CarSignalsController.onMethodCall` (Kotlin) that reuses the existing `SimulatorState.apply(kind, value)` + `onSimulatedEvent(event)` — the exact same logic `SimulateReceiver.handleSimulate` already calls — so it's additive and automatically a safe no-op on a real car with AdaptAPI selected (`simSource` stays null, same as today's broadcast path). Added a matching abstract `CarSignals.simulate(CarSignalEvent)` port method: `FakeCarSignals` implements it via the existing `relay()`; `NativeCarSignals` encodes the event to the same kind/value string format `SimulatorState.apply` parses and calls the new method channel action.
3. **Forcing the demo blinker to `hazard` (always-active) broke a widget test** (`settings_home_screen_test.dart`, "HUD tile navigates to HudSettingsScreen"): `BlinkerWidget`'s `AnimationController.repeat()` never settles once the blinker is forced active, so `pumpAndSettle()` hung. Fixed the test to `pump()` past the route transition instead of `pumpAndSettle()`; left a comment explaining why (Block 0026, not a flake).
4. **Forcing `charging=true` in the demo surfaced a real, pre-existing overflow bug in `BatteryWidget`**: only the icon+pct row was wrapped in `FittedBox`; the temp/charging-stats rows below it were not, so under tight constraints (a small test viewport) the Column overflowed once all three rows were showing simultaneously — previously unreachable because `charging` was never true in any existing test's default state. Fixed properly (not routed around): moved the `FittedBox(fit: scaleDown)` to wrap the whole Column, not just the icon row. Verified with the full 228-test suite green.
5. Two on-disk copies of the `drive-zee-app` SKILL.md (`.claude/skills/...` and `.agents/skills/...`) are hardlinked (editing one edits both, confirmed via `cp` reporting "identical, not copied") — only needed one explicit edit.

## Notes
Born from a live debugging session (2026-07-29): the "static preview" the user expected while
tinkering with blinker config on T2 was in fact the *live* `HudPreview`, and it went dark the
moment the injected `blinker` signal was set back to `off` — surfacing that the screen was
quietly serving two incompatible use cases (User: "show me the look I configured" vs. Developer:
"let me fire events and watch the HUD react") through one live-signal-only widget. This Block is
the reconciliation.

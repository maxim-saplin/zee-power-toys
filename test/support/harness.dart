/// Shared widget-test harness for zee-power-toys.
///
/// Every screen/widget test needs the same six [ProviderScope] overrides
/// (config store, car signals, minimap host, HUD host, installer, system
/// config) so the widget tree never touches a real platform channel. Before
/// this file existed, that boilerplate was copy-pasted into seven test files
/// as near-identical `wrapWithProviders`/`_wrap` closures — this is the one
/// place it lives now.
///
/// ⚠️ NEVER call `tester.pumpAndSettle()` on a subtree containing
/// [BlinkerWidget] (directly, or nested inside `HudRoot`/`HudPreview`/the
/// HUD Settings Config Preview). Its `AnimationController.repeat()` never
/// settles, so `pumpAndSettle()` spins until the 10-minute test timeout.
/// Use explicit `await tester.pump(const Duration(...))` steps instead — see
/// `test/widgets/hud_root_test.dart`'s BlinkerWidget group, and
/// `test/screens/settings_home_screen_test.dart`'s "HUD tile navigates to
/// HudSettingsScreen" test, for the pattern. This bit us once for real:
/// `docs/issues/0026-*.md`, Reconciliation item 3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/providers/usb_mode.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/installer.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';
import 'package:zee_power_toys/services/system_config.dart';
import 'package:zee_power_toys/services/usb_mode.dart';

/// Seeds `SharedPreferences` with an empty in-memory store so
/// [SharedPrefsConfigStore] never touches the filesystem/platform channel
/// during a test. Pass this straight to `setUp`:
///
/// ```dart
/// setUp(useMockPrefs);
/// ```
void useMockPrefs() {
  SharedPreferences.setMockInitialValues({});
}

/// Wraps [child] in a minimal [ProviderScope] with in-memory fake services,
/// then in a [MaterialApp].
///
/// This is the one shared shape behind what used to be seven copy-pasted
/// `wrapWithProviders`/`_wrap` helpers. The six standard overrides
/// (config store, car signals, minimap host, HUD host, installer, system
/// config) are always present; every fake can be swapped for a specific
/// instance via the named params below, and [usbMode] is only overridden
/// when a value is supplied (most tests never touch `usbModeProvider`).
///
/// - [config]: seeds a freshly-created [SharedPrefsConfigStore] synchronously
///   (via [ConfigStore.setConfig], not awaited — `setConfig` updates `.value`
///   before its first `await`, so the widget sees it on first build). Ignored
///   if [store] is supplied — pass a config to an already-built [store] via
///   your own fixture instead.
/// - [store]: use an already-constructed (and possibly already-loaded)
///   [ConfigStore] instead of letting this helper create one. Several screen
///   tests need `await store.load()` / `await store.setConfig(...)` to
///   resolve before pumping, which requires building the store outside this
///   synchronous helper.
/// - [localizations]: when true (the default), wires up
///   [AppLocalizations.localizationsDelegates] and
///   [AppLocalizations.supportedLocales] — required for screens that read
///   localized strings. Set false for widget tests that never touch
///   localization and don't want the extra delegates in the tree.
/// - [scaffold]: when true, wraps [child] in a `Scaffold` body — some widgets
///   (e.g. `BatteryWidget`) expect Material ancestry a bare `home:` doesn't
///   provide.
/// - [installer], [systemConfig], [usbMode]: per-service overrides for the
///   screen tests that need to inject a specific fake (e.g. `FakeInstaller`
///   with a scripted progress stream, `FakeSystemConfig(unsupported: true)`).
Widget wrapWithProviders(
  Widget child, {
  AppConfig? config,
  FakeCarSignals? signals,
  ConfigStore? store,
  bool localizations = true,
  bool scaffold = false,
  Installer? installer,
  SystemConfig? systemConfig,
  UsbModePort? usbMode,
}) {
  final effectiveStore = store ?? SharedPrefsConfigStore();
  if (config != null) {
    // Seed synchronously so the widget sees it on first build.
    effectiveStore.setConfig(config);
  }

  final home = scaffold ? Scaffold(body: child) : child;

  return ProviderScope(
    overrides: [
      configStoreProvider.overrideWithValue(effectiveStore),
      carSignalsProvider.overrideWithValue(signals ?? FakeCarSignals()),
      minimapHostProvider.overrideWithValue(FakeMinimapHost()),
      hudHostProvider.overrideWithValue(FakeHudHost()),
      installerProvider.overrideWithValue(installer ?? FakeInstaller()),
      systemConfigProvider.overrideWithValue(systemConfig ?? FakeSystemConfig()),
      if (usbMode != null) usbModeProvider.overrideWithValue(usbMode),
    ],
    child: localizations
        ? MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          )
        : MaterialApp(home: home),
  );
}

/// Sets the test surface to [size] (and, optionally, [dpr]), pumps [child],
/// and settles the first frame with a single `tester.pump()`.
///
/// Folds the `setSurfaceSize` + `addTearDown(() => setSurfaceSize(null))` +
/// `pumpWidget` + `pump()` sequence that used to be repeated ~12 times across
/// the widget tests. Only use this where that exact sequence applies —
/// i.e. nothing needs to happen between `pumpWidget` and the settling
/// `pump()` (no signal emission, no tap). Tests that emit a signal or need
/// multiple pumps between frames call `tester.binding.setSurfaceSize` and
/// `tester.pumpWidget`/`tester.pump` directly instead.
///
/// [dpr] is left `null` by default — the test binding's own device pixel
/// ratio (3.0, not 1.0) is left untouched unless a test explicitly needs a
/// different one, so this never silently changes rendering scale for
/// existing tests that never set it.
///
/// Do not follow this with `pumpAndSettle()` if [child] contains a
/// [BlinkerWidget] — see the warning at the top of this file.
Future<void> pumpHud(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1024, 576),
  double? dpr,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  if (dpr != null) {
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(child);
  await tester.pump();
}

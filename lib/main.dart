import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/dhu_app.dart';
import 'app/hud_app.dart';
import 'debug/agent_extensions.dart';
import 'providers/services.dart';
import 'relay/hub.dart';
import 'services/adapters/native_car_signals.dart';
import 'services/adapters/native_minimap_host.dart';
import 'services/car_signals.dart';
import 'services/fakes/fake_car_signals.dart';
import 'services/fakes/fake_hud_host.dart';
import 'services/fakes/fake_installer.dart';
import 'services/fakes/fake_minimap_host.dart';
import 'services/fakes/fake_system_config.dart';
import 'services/minimap_host.dart';
import 'services/shared_prefs_config_store.dart';

// ---------------------------------------------------------------------------
// Entrypoint dispatcher.
//
// T1 desktop: desktop_multi_window 0.3.0 re-runs THIS main() with args
//   ['multi_window', windowId, userArgs] for the HUD sub-window.
//
// T2 Android: FlutterEngineGroup in Kotlin launches the HUD engine via the
//   named Dart entrypoint "hudEntry" (see @pragma below).  main() on Android
//   always → dhuMain; the native host creates the HUD engine separately.
// ---------------------------------------------------------------------------
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty && args.first == 'multi_window') {
    // T1: desktop_multi_window sub-window re-run — start the HUD isolate.
    hudMain(args);
  } else {
    dhuMain(args);
  }
}

/// Android HUD entrypoint — invoked by FlutterEngineGroup via DartEntrypoint.
///
/// @pragma('vm:entry-point') prevents tree-shaking in release/profile builds.
/// ADR 0001: the HUD engine runs hudMain on both T1 and T2; only the caller
/// differs (desktop_multi_window on T1, native FlutterEngineGroup on T2).
/// WidgetsFlutterBinding must be initialised here before hudMain accesses
/// platform channels (SharedPrefs does so via its BinaryMessenger on load).
@pragma('vm:entry-point')
void hudEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  hudMain(const []);
}

// ---------------------------------------------------------------------------
// DHU — primary surface; owns creating the HUD window on T1 desktop.
// ---------------------------------------------------------------------------
Future<void> dhuMain(List<String> args) async {
  final store = SharedPrefsConfigStore();
  await store.load();

  // On Android, the DHU engine hosts the native CarSignalsController.
  // NativeCarSignals subscribes to the EventChannel and calls start() on init.
  // On T1 desktop, the in-process FakeCarSignals is used as before.
  final CarSignals carSignalsRaw =
      (!kIsWeb && Platform.isAndroid) ? NativeCarSignals() : FakeCarSignals();

  // On Android, the DHU drives the native MinimapView via NativeMinimapHost.
  // On T1 desktop the in-process FakeMinimapHost is used (no native surface).
  final MinimapHost minimapHostRaw =
      (!kIsWeb && Platform.isAndroid) ? NativeMinimapHost() : FakeMinimapHost();

  // Relay every config change to the HUD isolate.
  // ADR 0003: only the event crosses — never the store object itself.
  store.changes.listen(pushConfigToHud);

  // Relay every car-signal event to the HUD isolate.
  // Subscribes to whatever CarSignals was injected — works for both fake and native.
  carSignalsRaw.events.listen(pushCarSignalToHud);

  registerZeeExtensions(
    surface: 'dhu',
    store: store,
    shotKey: dhuShotKey,
    carSignals: carSignalsRaw,
    minimapHost: minimapHostRaw,
    // onSetConfig is null: the store.changes.listen above handles relay.
  );

  runApp(
    ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(carSignalsRaw),
        minimapHostProvider.overrideWithValue(minimapHostRaw),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: const _DhuRoot(),
    ),
  );
}

// ---------------------------------------------------------------------------
// HUD — secondary surface; spawned by desktop_multi_window (T1) or by the
// native FlutterEngineGroup host (T2 Android).
// ---------------------------------------------------------------------------
void hudMain(List<String> args) {
  // HUD owns its own CarSignals instance; state arrives only via the relay.
  // ADR 0003: each isolate has its own FakeCarSignals; the DHU one is the source.
  final store = SharedPrefsConfigStore();
  final carSignals = FakeCarSignals();

  registerZeeExtensions(
    surface: 'hud',
    store: store,
    shotKey: hudShotKey,
    carSignals: carSignals,
  );

  // Seed from persisted prefs, then arm the relay listener.
  store.load().then((_) {
    listenForRelay(
      onConfig: (cfg) => store.setConfig(cfg),
      onCarSignal: carSignals.relay, // re-emit on the HUD-side fake
    );
  });

  runApp(
    ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(carSignals),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: const HudApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// DHU root widget — creates the HUD window after first frame (T1 desktop only).
// On Android (T2) the native host creates the HUD engine; we must NOT call
// WindowController.create() there as desktop_multi_window is desktop-only.
// ---------------------------------------------------------------------------
class _DhuRoot extends StatefulWidget {
  const _DhuRoot();
  @override
  State<_DhuRoot> createState() => _DhuRootState();
}

class _DhuRootState extends State<_DhuRoot> {
  WindowController? _hud;

  @override
  void initState() {
    super.initState();
    // Only create the HUD window on desktop; the native host owns it on Android.
    if (_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _createHud());
    }
  }

  Future<void> _createHud() async {
    if (_hud != null) return; // idempotency guard
    try {
      final WindowController c = await WindowController.create(
        const WindowConfiguration(arguments: 'hud', hiddenAtLaunch: true),
      );
      await c.show();
      if (!mounted) return;
      setState(() => _hud = c);
    } catch (e) {
      debugPrint('DHU: failed to create HUD window: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const DhuApp();
  }
}

/// True when running on a desktop platform (Linux/macOS/Windows).
/// kIsWeb guard ensures Platform.isX calls are not made in a web context.
bool get _isDesktop =>
    !kIsWeb &&
    (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

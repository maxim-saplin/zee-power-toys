import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/dhu_app.dart';
import 'app/hud_app.dart';
import 'debug/agent_extensions.dart';
import 'providers/services.dart';
import 'relay/hub.dart';
import 'services/fakes/fake_car_signals.dart';
import 'services/fakes/fake_hud_host.dart';
import 'services/fakes/fake_installer.dart';
import 'services/fakes/fake_minimap_host.dart';
import 'services/fakes/fake_system_config.dart';
import 'services/shared_prefs_config_store.dart';

// ---------------------------------------------------------------------------
// Entrypoint dispatcher.
//
// RECONCILIATION NOTE: Block 0001's spec mentions a separate
// @pragma('vm:entry-point') hudMain() — that is the Android FlutterEngineGroup
// model (a named Dart entrypoint invoked by Kotlin via DartEntrypoint).
// On T1 desktop, desktop_multi_window 0.3.0 re-runs THIS main() with args
// ['multi_window', windowId, userArgs]. The HUD path is therefore selected by
// branching inside main(), NOT via a separate Flutter entrypoint. The separate
// @pragma hudMain is added in a later Android Block (T2).
// ---------------------------------------------------------------------------
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty && args.first == 'multi_window') {
    hudMain(args);
  } else {
    dhuMain(args);
  }
}

// ---------------------------------------------------------------------------
// DHU — primary surface; owns creating the HUD window.
// ---------------------------------------------------------------------------
Future<void> dhuMain(List<String> args) async {
  final store = SharedPrefsConfigStore();
  await store.load();

  final carSignals = FakeCarSignals();

  // Relay every config change to the HUD isolate.
  // ADR 0003: only the event crosses — never the store object itself.
  store.changes.listen(pushConfigToHud);

  // Relay every car-signal event to the HUD isolate.
  carSignals.events.listen(pushCarSignalToHud);

  registerZeeExtensions(
    surface: 'dhu',
    store: store,
    shotKey: dhuShotKey,
    carSignals: carSignals,
    // onSetConfig is null: the store.changes.listen above handles relay.
  );

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
      child: const _DhuRoot(),
    ),
  );
}

// ---------------------------------------------------------------------------
// HUD — secondary surface; spawned by desktop_multi_window inside DHU's process.
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
// DHU root widget — creates the HUD window after first frame.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _createHud());
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

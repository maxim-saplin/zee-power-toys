import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/dhu_app.dart';
import 'app/hud_app.dart';
import 'debug/agent_extensions.dart';
import 'providers/services.dart';
import 'relay/hub.dart';
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

  // Relay every config change to the HUD isolate over the native hub channel.
  // ADR 0003: only the event crosses — never the store object itself.
  store.changes.listen(pushConfigToHud);

  registerZeeExtensions(
    surface: 'dhu',
    store: store,
    shotKey: dhuShotKey,
    // onSetConfig is null: the store.changes.listen above handles relay.
  );

  runApp(
    ProviderScope(
      overrides: [configStoreProvider.overrideWithValue(store)],
      child: const _DhuRoot(),
    ),
  );
}

// ---------------------------------------------------------------------------
// HUD — secondary surface; spawned by desktop_multi_window inside DHU's process.
// ---------------------------------------------------------------------------
void hudMain(List<String> args) {
  // HUD owns its own ConfigStore; state arrives only via the relay (ADR 0003).
  final store = SharedPrefsConfigStore();

  registerZeeExtensions(
    surface: 'hud',
    store: store,
    shotKey: hudShotKey,
  );

  // Seed from persisted prefs, then arm the relay listener.
  store.load().then((_) {
    listenForConfig((cfg) => store.setConfig(cfg));
  });

  runApp(
    ProviderScope(
      overrides: [configStoreProvider.overrideWithValue(store)],
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

import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/dhu_app.dart';
import 'app/hud_app.dart';
import 'debug/agent_extensions.dart';
import 'providers/services.dart';
import 'providers/usb_mode.dart';
import 'relay/hub.dart';
import 'services/adapters/native_car_signals.dart';
import 'services/adapters/native_hud_host.dart';
import 'services/adapters/native_installer.dart';
import 'services/adapters/native_minimap_host.dart';
import 'services/adapters/native_system_config.dart';
import 'services/adapters/native_usb_mode.dart';
import 'services/car_signals.dart';
import 'services/fakes/fake_car_signals.dart';
import 'services/fakes/fake_hud_host.dart';
import 'services/fakes/fake_installer.dart';
import 'services/fakes/fake_minimap_host.dart';
import 'services/fakes/fake_system_config.dart';
import 'services/fakes/fake_usb_mode.dart';
import 'services/config_store.dart';
import 'services/hud_host.dart';
import 'services/installer.dart';
import 'services/minimap_host.dart';
import 'services/shared_prefs_config_store.dart';
import 'services/system_config.dart';
import 'services/usb_mode.dart';

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

  // On Android, use the NativeInstaller which communicates via the
  // zee/installer EventChannel/MethodChannel to download+install APKs.
  // On T1 desktop, FakeInstaller simulates the progress sequence.
  final Installer installerRaw =
      (!kIsWeb && Platform.isAndroid) ? NativeInstaller() : FakeInstaller();

  // On Android, use NativeSystemConfig which reads the real system locale
  // and attempts privileged writes via AdaptAPI (guarded; T3-only on success).
  // On T1 desktop, FakeSystemConfig provides in-memory state.
  final SystemConfig systemConfigRaw;
  if (!kIsWeb && Platform.isAndroid) {
    final native = NativeSystemConfig();
    await native.loadSystemLocale();
    systemConfigRaw = native;
  } else {
    systemConfigRaw = FakeSystemConfig();
  }

  // On Android, NativeUsbMode talks to UsbModeController via zee/usb_mode.
  // On T1 desktop, FakeUsbMode provides writable in-memory state.
  final UsbModePort usbModeRaw =
      (!kIsWeb && Platform.isAndroid) ? NativeUsbMode() : FakeUsbMode();

  // On Android, NativeHudHost wraps the zee/hud_lifecycle channel so toggling
  // hudEnabled tears down / re-spawns the HUD FlutterEngine (QA4-1, ADR 0001).
  // On T1 desktop FakeHudHost manages the desktop_multi_window second window.
  final HudHost hudHostRaw =
      (!kIsWeb && Platform.isAndroid) ? NativeHudHost() : FakeHudHost();

  // Relay every config change to the HUD isolate.
  // ADR 0003: only the event crosses — never the store object itself.
  store.changes.listen(pushConfigToHud);

  // Wire MinimapConfig → MinimapHost: enable/disable + Safe-Area-relative
  // bounds derived from the preset (or manual fracs in advanced mode).
  // Idempotent on the native side (setMinimap is a NOOP when already in state).
  // Fires once on startup (persisted config) and on every subsequent change.
  _applyMinimapConfig(minimapHostRaw, store.value);

  // Listen for dynamic hudEnabled toggles: show()/hide() the HUD engine.
  // store.changes only fires on explicit setConfig; the initial state at boot
  // is handled natively (ConfigShim.readHudEnabled in setupHud). We track the
  // last value so we only act on actual transitions (QA4-1).
  bool lastHudEnabled = store.value.hudEnabled;
  store.changes.listen((cfg) {
    if (cfg.hudEnabled != lastHudEnabled) {
      lastHudEnabled = cfg.hudEnabled;
      if (cfg.hudEnabled) {
        hudHostRaw.show().catchError((_) {});
      } else {
        hudHostRaw.hide().catchError((_) {});
      }
    }
    _applyMinimapConfig(minimapHostRaw, cfg);
  });

  // After setupHud() completes, native fires hudReady with the actual HUD
  // display dimensions (e.g. 1280×720 on the emulator).  Update _hudW/_hudH
  // and re-apply minimap config so bounds use the real display (QA1-2, QA1-4).
  if (minimapHostRaw is NativeMinimapHost) {
    minimapHostRaw.onHudReady.listen((size) {
      _hudW = size.$1;
      _hudH = size.$2;
      _applyMinimapConfig(minimapHostRaw, store.value);
    });
  }

  // Relay every car-signal event to the HUD isolate.
  // Subscribes to whatever CarSignals was injected — works for both fake and native.
  carSignalsRaw.events.listen(pushCarSignalToHud);

  registerZeeExtensions(
    surface: 'dhu',
    store: store,
    shotKey: dhuShotKey,
    carSignals: carSignalsRaw,
    minimapHost: minimapHostRaw,
    installer: installerRaw,
    systemConfig: systemConfigRaw,
    usbMode: usbModeRaw,
    // onSetConfig is null: the store.changes.listen above handles relay.
    // getBootState: on Android, query the native FGS singleton for boot status.
    // On other platforms (T1 desktop) the callback is not provided.
    getBootState: (!kIsWeb && Platform.isAndroid) ? getBootStateAsync : null,
  );

  runApp(
    ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(carSignalsRaw),
        minimapHostProvider.overrideWithValue(minimapHostRaw),
        hudHostProvider.overrideWithValue(hudHostRaw),
        installerProvider.overrideWithValue(installerRaw),
        systemConfigProvider.overrideWithValue(systemConfigRaw),
        usbModeProvider.overrideWithValue(usbModeRaw),
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
        usbModeProvider.overrideWithValue(FakeUsbMode()),
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

// ---------------------------------------------------------------------------
// MinimapHost config wiring — preset→geometry applied on config changes.
//
// Default HUD backing-display dimensions (Zeekr S2 nominal 1024×576 @ 213 dpi).
// Overwritten at runtime when native reports the actual display via hudReady
// (see NativeMinimapHost.onHudReady in dhuMain — QA1-2).  On T1 desktop the
// FakeMinimapHost ignores physical pixel bounds, so the default values are fine.
// ---------------------------------------------------------------------------
// ignore: prefer_final_fields — intentionally mutable; updated by onHudReady.
double _hudW = 1024.0;
// ignore: prefer_final_fields
double _hudH = 576.0;

/// Apply [cfg.minimap] to [host]: enable/disable the MinimapView and update
/// its Safe-Area-relative bounds from the active preset (or manual fractions
/// in advanced mode).
///
/// Called once on startup (persisted config) and on every config change.
/// Both enable() and setBounds() are idempotent on the native side.
/// Errors are swallowed: MinimapHost may not be ready on startup (T1 fake is
/// always ready; T2 native is ready after setupHud completes).
void _applyMinimapConfig(MinimapHost host, AppConfig cfg) {
  final mm = cfg.minimap;
  host.enable(mm.enabled).catchError((_) {});
  if (!mm.enabled) return;

  final sa = cfg.safeArea;
  final saLeft = sa.left * _hudW;
  final saTop = sa.top * _hudH;
  final saW = (sa.right - sa.left) * _hudW;
  final saH = (sa.bottom - sa.top) * _hudH;

  final fracs = mm.resolvedFracs;
  final bounds = Rect.fromLTWH(saLeft, saTop, saW * fracs.$1, saH * fracs.$2);
  host.setBounds(bounds).catchError((_) {});
}

// ---------------------------------------------------------------------------
// Boot state query — Feedback Loop visibility (Block 0010).
//
// Queries the native zee/boot MethodChannel for FGS running state and config
// read status.  Used as the getBootState callback in registerZeeExtensions.
// On T1 desktop (no native channel) returns a minimal error map.
// ---------------------------------------------------------------------------
const _bootChannel = MethodChannel('zee/boot');

/// Async boot state query: calls zee/boot.getBootState on the native side.
/// Returns best-effort data; on channel failure returns an error map.
Future<Map<String, Object?>> getBootStateAsync() async {
  try {
    final result = await _bootChannel.invokeMapMethod<String, Object?>('getBootState');
    return result ?? <String, Object?>{'fgsRunning': false, 'configReadOk': false};
  } catch (e) {
    return <String, Object?>{'error': '$e', 'fgsRunning': false, 'configReadOk': false};
  }
}

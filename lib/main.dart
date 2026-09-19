import 'dart:io' show Directory, Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/dhu_app.dart';
import 'app/hud_app.dart';
import 'debug/agent_extensions.dart';
import 'providers/hud_geometry.dart';
import 'providers/services.dart';
import 'providers/usb_mode.dart';
import 'relay/hub.dart';
import 'services/adapters/native_car_signals.dart';
import 'services/adapters/native_hud_host.dart';
import 'services/adapters/native_installer.dart';
import 'services/adapters/native_package_status.dart';
import 'services/adapters/native_minimap_host.dart';
import 'services/adapters/native_system_config.dart';
import 'services/adapters/native_usb_mode.dart';
import 'services/car_signals.dart';
import 'services/fakes/fake_car_signals.dart';
import 'services/fakes/fake_hud_host.dart';
import 'services/fakes/fake_installer.dart';
import 'services/fakes/fake_package_status.dart';
import 'services/default_speedcam_service.dart';
import 'services/fakes/fake_speedcam_service.dart';
import 'services/fakes/fake_speedcam_pack_store.dart';
import 'services/speedcam_pack_store.dart';
import 'services/fakes/fake_minimap_host.dart';
import 'services/fakes/fake_system_config.dart';
import 'services/fakes/fake_usb_mode.dart';
import 'services/config_store.dart';
import 'services/hud_host.dart';
import 'services/installer.dart';
import 'services/package_status.dart';
import 'services/speedcam.dart';
import 'services/minimap_host.dart';
import 'services/minimap_viewport.dart';
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
  final CarSignals carSignalsRaw = (!kIsWeb && Platform.isAndroid)
      ? NativeCarSignals()
      : FakeCarSignals();

  // On Android, the DHU drives the native MinimapView via NativeMinimapHost.
  // On T1 desktop the in-process FakeMinimapHost is used (no native surface).
  final MinimapHost minimapHostRaw = (!kIsWeb && Platform.isAndroid)
      ? NativeMinimapHost()
      : FakeMinimapHost();

  // On Android, use the NativeInstaller which communicates via the
  // zee/installer EventChannel/MethodChannel to download+install APKs.
  // On T1 desktop, FakeInstaller simulates the progress sequence.
  final Installer installerRaw = (!kIsWeb && Platform.isAndroid)
      ? NativeInstaller()
      : FakeInstaller();

  final PackageStatus packageStatusRaw = (!kIsWeb && Platform.isAndroid)
      ? NativePackageStatus()
      : FakePackageStatus();

  // Speedcam packs (0031): file cache on device/desktop; Fake on web.
  final SpeedcamPackStore speedcamPackRaw;
  if (kIsWeb) {
    speedcamPackRaw = FakeSpeedcamPackStore();
  } else {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/speedcam_packs');
    speedcamPackRaw = FileSpeedcamPackStore(root: root);
  }

  // Speedcam (0032): DefaultService loads pack cams; Fake samples only as fallback.
  final SpeedcamService speedcamRaw = DefaultSpeedcamService(
    packStore: speedcamPackRaw,
  );

  // On Android, use NativeSystemConfig which reads the real system locale
  // and attempts privileged writes via AdaptAPI (guarded; T3-only on success).
  // On T1 desktop, FakeSystemConfig provides in-memory state.
  final SystemConfig systemConfigRaw;
  if (!kIsWeb && Platform.isAndroid) {
    final native = NativeSystemConfig();
    await native.loadSystemLocale();
    systemConfigRaw = native;
  } else {
    // T1 desktop: system/cluster language writes are not supported off-car.
    // unsupported:true → FakeSystemConfig returns {ok:false, reason:"unsupported-on-device"}
    // for system/cluster writes, and clusterSupported() returns false, so the
    // Language settings screen disables the System and Cluster pickers (QA3-3).
    systemConfigRaw = FakeSystemConfig(unsupported: true);
  }

  // On Android, NativeUsbMode talks to UsbModeController via zee/usb_mode.
  // On T1 desktop, FakeUsbMode provides writable in-memory state.
  final UsbModePort usbModeRaw = (!kIsWeb && Platform.isAndroid)
      ? NativeUsbMode()
      : FakeUsbMode();

  // On Android, NativeHudHost wraps the zee/hud_lifecycle channel so toggling
  // hudEnabled tears down / re-spawns the HUD FlutterEngine (QA4-1, ADR 0001).
  // On T1 desktop FakeHudHost manages the desktop_multi_window second window.
  final HudHost hudHostRaw = (!kIsWeb && Platform.isAndroid)
      ? NativeHudHost()
      : FakeHudHost();

  // Explicit ProviderContainer (rather than a bare declarative ProviderScope)
  // so hudGeometryProvider can be updated from the onHudReady stream listener
  // below, which fires outside the widget tree/build phase — a plain
  // ProviderScope gives no handle to write to a provider from there.
  final container = ProviderContainer(
    overrides: [
      configStoreProvider.overrideWithValue(store),
      carSignalsProvider.overrideWithValue(carSignalsRaw),
      minimapHostProvider.overrideWithValue(minimapHostRaw),
      hudHostProvider.overrideWithValue(hudHostRaw),
      installerProvider.overrideWithValue(installerRaw),
      packageStatusProvider.overrideWithValue(packageStatusRaw),
      speedcamServiceProvider.overrideWithValue(speedcamRaw),
      speedcamPackStoreProvider.overrideWithValue(speedcamPackRaw),
      systemConfigProvider.overrideWithValue(systemConfigRaw),
      usbModeProvider.overrideWithValue(usbModeRaw),
    ],
  );

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
  // display dimensions + dpi (e.g. 1024×576 @ 213 dpi on the emulator and the car).
  // Update _hudW/_hudH/_hudDpi and recompute the HudSafeArea fractions from
  // phase0 dp constants × real density so the Flutter overlay (battery/blinker)
  // uses the correct Safe Area for this display (not the baked-in T3 defaults).
  // Then re-apply minimap config with the real display metrics (QA1-2, QA1-4).
  if (minimapHostRaw is NativeMinimapHost) {
    minimapHostRaw.onHudReady.listen((dims) {
      _hudW = dims.$1;
      _hudH = dims.$2;
      _hudDpi = dims.$3.toInt();
      _hudDisplayId = dims.$4;
      // Recompute HudSafeArea fractions from phase0 dp constants × actual density
      // and relay to the HUD Flutter overlay via the config store + relay.
      final fracs = computeHudSafeAreaFracs(
        displayW: _hudW,
        displayH: _hudH,
        dpi: _hudDpi.toDouble(),
      );
      store.setConfig(
        store.value.copyWith(
          safeArea: store.value.safeArea.copyWith(
            left: fracs.left,
            top: fracs.top,
            right: fracs.right,
            bottom: fracs.bottom,
          ),
        ),
      );
      // setConfig fires store.changes → pushConfigToHud relay → HUD overlay updated.
      // _applyMinimapConfig will also be called via the store.changes listener above,
      // with updated _hudW/_hudH/_hudDpi already in place.

      // Surface the real HUD geometry to ordinary app UI (not just the debug
      // ext.zee.readViewModel bridge) so a screen can honestly report which
      // display it is actually driving (Task 1 — signal-source/HUD honesty).
      container.read(hudGeometryProvider.notifier).state = HudGeometryInfo(
        displayId: _hudDisplayId,
        w: _hudW.toInt(),
        h: _hudH.toInt(),
        dpi: _hudDpi,
      );
    });
  }

  // Relay every car-signal event to the HUD isolate.
  // Subscribes to whatever CarSignals was injected — works for both fake and native.
  carSignalsRaw.events.listen(pushCarSignalToHud);
  // Speedcam (0033): DHU owns pack+pose; HUD paints CRT from relay.
  speedcamRaw.snapshots.listen(pushSpeedcamToHud);

  registerZeeExtensions(
    surface: 'dhu',
    store: store,
    shotKey: dhuShotKey,
    carSignals: carSignalsRaw,
    minimapHost: minimapHostRaw,
    installer: installerRaw,
    systemConfig: systemConfigRaw,
    usbMode: usbModeRaw,
    speedcam: speedcamRaw,
    speedcamPack: speedcamPackRaw,
    // onSetConfig is null: the store.changes.listen above handles relay.
    // getBootState: on Android, query the native FGS singleton for boot status.
    // On other platforms (T1 desktop) the callback is not provided.
    getBootState: (!kIsWeb && Platform.isAndroid) ? getBootStateAsync : null,
    // Block 0027: the app reports its own HUD geometry + minimap ROI so the
    // Feedback Loop never has to reimplement computeMinimapViewport() in
    // Python and risk the two copies drifting apart. Only meaningful on the
    // DHU surface (only dhuMain holds a NativeMinimapHost + these holders).
    getHudGeometry: () => <String, Object?>{
      'displayId': _hudDisplayId,
      'w': _hudW.toInt(),
      'h': _hudH.toInt(),
      'dpi': _hudDpi,
    },
    getMinimapViewport: () => _lastMinimapBounds,
    getMinimapNative: () => _lastMinimapNative,
    onMinimapNativeResult: (r) => _lastMinimapNative = r,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const _DhuRoot()),
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
  // HUD Speedcam is a relay sink — pack+pose live on DHU (ADR 0003).
  final speedcam = FakeSpeedcamService();
  final speedcamPack = FakeSpeedcamPackStore();

  registerZeeExtensions(
    surface: 'hud',
    store: store,
    shotKey: hudShotKey,
    carSignals: carSignals,
    speedcam: speedcam,
    speedcamPack: speedcamPack,
  );

  // Seed from persisted prefs, then arm the relay listener.
  store.load().then((_) {
    listenForRelay(
      onConfig: (cfg) => store.setConfig(cfg),
      onCarSignal: carSignals.relay, // re-emit on the HUD-side fake
      onSpeedcam: speedcam.applyRelaySnapshot,
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
        packageStatusProvider.overrideWithValue(FakePackageStatus()),
        speedcamServiceProvider.overrideWithValue(speedcam),
        speedcamPackStoreProvider.overrideWithValue(speedcamPack),
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
    !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

// ---------------------------------------------------------------------------
// MinimapHost config wiring — phase0 square viewport geometry (Block 0025).
//
// HUD display metrics — defaults for Zeekr S2 (1024×576 @ 213 dpi).
// Overwritten at runtime when native reports the actual display via hudReady
// (see NativeMinimapHost.onHudReady in dhuMain — QA1-2).  On T1 desktop the
// FakeMinimapHost ignores physical pixel bounds, so the defaults are fine.
// ---------------------------------------------------------------------------
// ignore: prefer_final_fields — intentionally mutable; updated by onHudReady.
double _hudW = 1024.0;
// ignore: prefer_final_fields
double _hudH = 576.0;
// ignore: prefer_final_fields
int _hudDpi = 213; // Zeekr S2 / T2 emulator density; updated from onHudReady.
// ignore: prefer_final_fields
/// Logical Android display id the HUD Presentation lives on (Block 0027).
/// Null until the first onHudReady (T1 desktop never reports one — no native
/// Presentation there). Read by ext.zee.readViewModel's `hud` field so the
/// Feedback Loop's native-composite capture never has to guess or hardcode
/// displayId — the app is the source of truth for its own geometry.
int? _hudDisplayId;

/// Last minimap viewport [Rect] computed by [_applyMinimapConfig] (Block
/// 0027) — the exact ROI the pixel verifier must crop to check the minimap,
/// regardless of whether the minimap is currently enabled (the geometry is
/// pure function of display metrics + preset, not of the enabled flag).
/// Read by ext.zee.readViewModel's `viewport` field.
Rect? _lastMinimapBounds;

/// Last native gate result returned by [MinimapHost.enable] (either from the
/// config-driven path below or a direct `ext.zee.minimap on=...` call — both
/// funnel through the same holder). Read by ext.zee.readViewModel's
/// `minimap.native` field so the Feedback Loop can see the native
/// availability gate ("applied:true" | "unavailable" | "no-minimap")
/// without a screenshot.
String? _lastMinimapNative;

/// Apply [cfg.minimap] to [host] using phase0's square viewport geometry.
///
/// Bounds are computed from the empirical phase0 Safe Area dp constants ×
/// real HUD display density, with the square's size fraction resolved from
/// [MinimapConfig.resolvedSizeFraction] — the preset's fraction, or the
/// manual Size-slider override in advanced mode (Task 2: the one continuous
/// slider that genuinely changes this rect, replacing the old dead
/// widthFrac/heightFrac sliders). The SQUARE_LEFT placement (square on the
/// left of the Safe Area) ensures no collision with the battery widget on
/// the right.
///
/// Phase0 pattern: setBounds BEFORE enable so the filterWrapper is sized to
/// the viewport rect before parkForYNavi triggers the YNavi surface start.
///
/// Called once on startup and on every config change (both paths are idempotent).
void _applyMinimapConfig(MinimapHost host, AppConfig cfg) {
  final mm = cfg.minimap;
  // Compute the phase0 square viewport from dp constants × real density.
  // Computed unconditionally (not gated on mm.enabled) so
  // ext.zee.readViewModel.viewport always reports the ROI the minimap WOULD
  // occupy — the Feedback Loop can crop it the moment minimap is enabled
  // without waiting on a second config round-trip (Block 0027).
  final bounds = computeMinimapViewport(
    displayW: _hudW,
    displayH: _hudH,
    dpi: _hudDpi.toDouble(),
    preset: mm.preset,
    sizeFraction: mm.resolvedSizeFraction,
  );
  _lastMinimapBounds = bounds;
  if (mm.enabled) {
    host.setBounds(bounds).catchError((_) {});
  }
  host
      .enable(mm.enabled)
      .then((r) => _lastMinimapNative = r)
      .catchError((e) => _lastMinimapNative = 'error:$e');
  // Look + content density (Block 0028): colour filter knobs + phase0
  // minimapScale (contentScale). Native cold-rebinds YNavi when scale changes.
  final scale = mm.contentScale.clamp(0.3, 1.0);
  final params = <String, Object?>{
    ...mm.looks.toParams(),
    'minimapScale': scale,
  };
  host.setParams(params).catchError((_) {});
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
    final result = await _bootChannel.invokeMapMethod<String, Object?>(
      'getBootState',
    );
    return result ??
        <String, Object?>{'fgsRunning': false, 'configReadOk': false};
  } catch (e) {
    return <String, Object?>{
      'error': '$e',
      'fgsRunning': false,
      'configReadOk': false,
    };
  }
}

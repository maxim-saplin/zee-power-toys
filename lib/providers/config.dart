import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/config_store.dart';
import 'services.dart';

/// Live AppConfig derived from the ConfigStore's change stream.
/// Seeded from store.value on first watch (synchronous), then updated on changes.
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  final store = ref.watch(configStoreProvider);
  return store.changes;
});

/// Current Safe Area rectangle, updated whenever the config changes.
final safeAreaProvider = Provider<HudSafeArea>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.safeArea,
    loading: () => ref.watch(configStoreProvider).value.safeArea,
    error: (e, _) => ref.watch(configStoreProvider).value.safeArea,
  );
});

/// Current blinker appearance config, updated whenever the config changes.
final blinkerConfigProvider = Provider<BlinkerConfig>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.blinker,
    loading: () => ref.watch(configStoreProvider).value.blinker,
    error: (e, _) => ref.watch(configStoreProvider).value.blinker,
  );
});

/// Current battery widget config, updated whenever the config changes.
final batteryConfigProvider = Provider<BatteryConfig>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.battery,
    loading: () => ref.watch(configStoreProvider).value.battery,
    error: (e, _) => ref.watch(configStoreProvider).value.battery,
  );
});

/// Current minimap config, updated whenever the config changes.
final minimapConfigProvider = Provider<MinimapConfig>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.minimap,
    loading: () => ref.watch(configStoreProvider).value.minimap,
    error: (e, _) => ref.watch(configStoreProvider).value.minimap,
  );
});

/// Whether a compatible YNavi mod is installed and detectable.
///
/// Queries MinimapHost.isYnaviAvailable() once on first watch.
/// On T1 the FakeMinimapHost returns its configurable field (default false).
/// On T2 Android the native PackageManager check runs.
final ynaviAvailableProvider = FutureProvider<bool>((ref) async {
  final host = ref.watch(minimapHostProvider);
  return host.isYnaviAvailable();
});

// `hudThemeFollowProvider` (exposing MinimapConfig.themeFollow) used to live
// here. Deleted along with the field it read — see the removal rationale in
// MinimapConfig's doc comment (lib/services/config_store.dart): the control
// had no truthful native destination (Block 0021 pins YNavi's night mode
// permanently; a light HUD contradicts the emissive-projector rule in
// CONTEXT.md), so it was deleted outright rather than left half-wired.

/// Whether the HUD engine should be spawned.
///
/// Read by native MainActivity.setupHud() via ConfigShim (ADR 0003) before
/// Flutter is up; this Dart-side provider keeps the Feedback Loop in sync.
/// Default true — HUD on unless the user explicitly disables it.
final hudEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.hudEnabled,
    loading: () => ref.watch(configStoreProvider).value.hudEnabled,
    error: (e, _) => ref.watch(configStoreProvider).value.hudEnabled,
  );
});

final speedcamConfigProvider = Provider<SpeedcamConfig>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.speedcam,
    loading: () => ref.watch(configStoreProvider).value.speedcam,
    error: (e, _) => ref.watch(configStoreProvider).value.speedcam,
  );
});


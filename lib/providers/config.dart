import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/config_store.dart';
import 'services.dart';

/// Live AppConfig derived from the ConfigStore's change stream.
/// Seeded from store.value on first watch (synchronous), then updated on changes.
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  final store = ref.watch(configStoreProvider);
  return store.changes;
});

/// Flat bool derived from appConfigProvider; falls back to store.value when
/// the stream has not yet emitted (first frame).
final hudBoxOnProvider = Provider<bool>((ref) {
  final async = ref.watch(appConfigProvider);
  // .when() avoids touching valueOrNull which does not exist in Riverpod 3.x.
  return async.when(
    data: (cfg) => cfg.hudBoxOn,
    loading: () => ref.watch(configStoreProvider).value.hudBoxOn,
    error: (e, _) => ref.watch(configStoreProvider).value.hudBoxOn,
  );
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

/// Resolved HUD brightness: when themeFollow='auto' this follows the system
/// brightness at the time of the last config read (cannot watch
/// MediaQuery from a plain Provider — UI consumers resolve it with
/// MediaQuery.platformBrightnessOf(context) when they need the live value).
///
/// This provider exposes the configured preference string so widgets can
/// quickly derive the effective brightness without re-reading the full config.
/// Values: 'auto' | 'dark' | 'light'.
final hudThemeFollowProvider = Provider<String>((ref) {
  final async = ref.watch(appConfigProvider);
  return async.when(
    data: (cfg) => cfg.minimap.themeFollow,
    loading: () => ref.watch(configStoreProvider).value.minimap.themeFollow,
    error: (e, _) => ref.watch(configStoreProvider).value.minimap.themeFollow,
  );
});

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

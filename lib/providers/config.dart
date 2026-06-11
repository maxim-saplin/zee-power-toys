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

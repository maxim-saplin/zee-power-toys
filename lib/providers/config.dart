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
  // valueOrNull is available on AsyncData; use when() to be explicit.
  return async.when(
    data: (cfg) => cfg.hudBoxOn,
    loading: () => ref.watch(configStoreProvider).value.hudBoxOn,
    error: (e, _) => ref.watch(configStoreProvider).value.hudBoxOn,
  );
});

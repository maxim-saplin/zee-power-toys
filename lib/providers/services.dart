import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/config_store.dart';

/// Abstract service provider — injected via ProviderScope.overrides at startup.
/// Each isolate gets its own instance; never shared across isolates (ADR 0003).
final configStoreProvider = Provider<ConfigStore>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

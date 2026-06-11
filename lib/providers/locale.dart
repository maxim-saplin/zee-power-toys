import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config.dart';
import 'services.dart';

/// Resolves the active [Locale] for the DHU MaterialApp.
///
/// Returns the persisted override from ConfigStore when set ('en' / 'ru');
/// returns null otherwise so MaterialApp follows the platform/system locale.
/// Null is the "follow system" signal — MaterialApp treats a null locale as
/// "use the platform locale" (Flutter docs: `locale` defaults to system locale
/// when null or when the value matches no supported locale, it falls back).
final appLocaleProvider = Provider<Locale?>((ref) {
  final async = ref.watch(appConfigProvider);
  final code = async.when(
    data: (cfg) => cfg.locale,
    loading: () => ref.watch(configStoreProvider).value.locale,
    // ignore: no_leading_underscores_for_local_identifiers
    error: (err, st) => ref.watch(configStoreProvider).value.locale,
  );
  if (code == null) return null;
  // Only accept the two supported codes; unknown strings fall back to system.
  if (code == 'en' || code == 'ru') return Locale(code);
  return null;
});

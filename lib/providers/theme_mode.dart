import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config.dart';
import 'services.dart';

/// Resolves the DHU [ThemeMode] from ConfigStore (`dark` / `light`).
///
/// HUD isolate must not watch this — [HudApp] is pinned to [ThemeMode.dark].
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final async = ref.watch(appConfigProvider);
  final raw = async.when(
    data: (cfg) => cfg.themeMode,
    loading: () => ref.watch(configStoreProvider).value.themeMode,
    error: (err, st) => ref.watch(configStoreProvider).value.themeMode,
  );
  return raw == 'light' ? ThemeMode.light : ThemeMode.dark;
});

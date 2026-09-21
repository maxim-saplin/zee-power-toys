import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config.dart';
import 'services.dart';

/// Resolves the DHU [ThemeMode] from ConfigStore (`auto` / `dark` / `light`).
///
/// - `auto` (default) → [ThemeMode.system] (follow platform brightness)
/// - `dark` / `light` → manual override
///
/// HUD isolate must not watch this — [HudApp] is pinned to [ThemeMode.dark].
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final async = ref.watch(appConfigProvider);
  final raw = async.when(
    data: (cfg) => cfg.themeMode,
    loading: () => ref.watch(configStoreProvider).value.themeMode,
    error: (err, st) => ref.watch(configStoreProvider).value.themeMode,
  );
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system; // auto / unknown
  }
});

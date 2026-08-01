import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import '../system_config.dart';

/// T1 fake for [SystemConfig].
///
/// Has two modes, controlled by [unsupported]:
///   false (default) — all writes succeed; in-memory state updated.
///     Use this mode in tests that verify the happy-path UI.
///   true  — writes return [ok: false, reason: "unsupported-on-device"]
///     AND clusterSupported() returns false.
///     Use this mode in tests that verify the disabled / car-only hint UI.
///
/// [systemLocale] defaults to [initial] (or 'en') — the fake cannot read the
/// real platform locale on T1, so the initial value is fixed at construction.
class FakeSystemConfig implements SystemConfig {
  FakeSystemConfig({Locale? initial, bool unsupported = false})
    : _systemLocale = initial ?? _platformLocale(),
      _unsupported = unsupported; // ignore: prefer_initializing_formals

  final bool _unsupported;

  Locale _systemLocale;

  /// The locale last passed to [setSystemLanguage] (null = unchanged).
  Locale? lastSystemLanguage;

  /// The locale last passed to [setClusterLanguage] (null = unchanged).
  Locale? lastClusterLanguage;

  @override
  Locale get systemLocale => _systemLocale;

  @override
  Future<LanguageSetResult> setSystemLanguage(Locale locale) async {
    if (_unsupported) {
      return const LanguageSetResult(
        ok: false,
        reason: 'unsupported-on-device',
      );
    }
    lastSystemLanguage = locale;
    _systemLocale = locale;
    return const LanguageSetResult(ok: true);
  }

  @override
  Future<LanguageSetResult> setClusterLanguage(Locale locale) async {
    if (_unsupported) {
      return const LanguageSetResult(
        ok: false,
        reason: 'unsupported-on-device',
      );
    }
    lastClusterLanguage = locale;
    return const LanguageSetResult(ok: true);
  }

  @override
  Future<bool> clusterSupported() async => !_unsupported;

  @override
  Future<bool> systemSupported() async => !_unsupported;

  /// Best-effort locale from the platform environment variable on Linux.
  /// Returns Locale('en') when the environment is unavailable.
  static Locale _platformLocale() {
    try {
      final lang = Platform.environment['LANG'] ?? '';
      // LANG is typically "en_US.UTF-8" or "ru_RU.UTF-8"
      final tag = lang.split('.').first; // "en_US" or "ru_RU"
      if (tag.length >= 2) {
        final parts = tag.split('_');
        if (parts.length >= 2) {
          return Locale(parts[0].toLowerCase(), parts[1].toUpperCase());
        }
        return Locale(tag.substring(0, 2).toLowerCase());
      }
    } catch (_) {}
    return const Locale('en');
  }
}

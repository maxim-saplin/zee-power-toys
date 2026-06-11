import 'dart:ui' show Locale;

import 'package:flutter/services.dart';

import '../system_config.dart';

/// Android implementation of [SystemConfig].
///
/// Communicates with the native [SystemConfigController] via:
///   MethodChannel "zee/system_config" — methods: systemLocale, setSystemLanguage,
///                                        setClusterLanguage, clusterSupported.
///
/// ── T3-only write paths (from phase0 ClusterLocaleProbe / SettingZeekrProbe) ──
///
///   setSystemLanguage:
///     Calls android.app.ActivityManager.updateConfiguration() with a new
///     Locale.  Requires android.permission.CHANGE_CONFIGURATION (signature-level
///     on AOSP; granted to Zeekr system APKs). On the emulator or stock Android
///     the native handler returns {ok:false, reason:"unsupported-on-device"}.
///
///   setClusterLanguage (Path 1 — ICarFunction):
///     com.ecarx.xui.adaptapi.car.Car.create(ctx)
///       → .getICarFunction()
///       → .setFunctionValue(LOCALE_FUNC_ID=0x20318a00, value)
///     value: 0 = Chinese, 1 = non-Chinese (binary locale flag used by the Zeekr
///     cluster HMI).
///
///   setClusterLanguage (Path 3 — IOtaSession, 37-language enum):
///     car.getIOtaSession().setSystemHMILanguage(langEnum)
///     Enum map: 11 = English_US, 30 = Russian.
///     Fallback: AdaptInternalManager.set("Adapt-OTA","SET_SYSTEM_HMI_LANGUAGE",…)
///
///   All reflective/privileged calls in the Kotlin layer are try-catched; the
///   result envelope {ok, reason} is always returned — never a channel exception.
///
/// ── T2 (emulator) behaviour ──
///   The AdaptAPI class is absent; the Kotlin handler catches ClassNotFoundException
///   and returns {ok:false, reason:"unsupported-on-device"}.  The Dart layer
///   surfaces this to the UI without crashing.
class NativeSystemConfig implements SystemConfig {
  static const _channel = MethodChannel('zee/system_config');

  /// Cache the initial system locale on first use; updated after a successful
  /// [setSystemLanguage] call so the UI stays in sync without requiring a requery.
  Locale? _cachedLocale;

  @override
  Locale get systemLocale => _cachedLocale ?? const Locale('en');

  /// Load the real system locale from the native side.
  ///
  /// Called once during DHU startup; also called if [systemLocale] has not been
  /// cached yet.  Returns Locale('en') on channel failure (safe default).
  Future<void> loadSystemLocale() async {
    try {
      final tag = await _channel.invokeMethod<String>('systemLocale');
      if (tag != null && tag.isNotEmpty) {
        _cachedLocale = _parseLocaleTag(tag);
      }
    } catch (_) {
      _cachedLocale = const Locale('en');
    }
  }

  @override
  Future<LanguageSetResult> setSystemLanguage(Locale locale) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'setSystemLanguage',
        {'languageTag': _toLanguageTag(locale)},
      );
      final result = _parseResult(raw);
      if (result.ok) {
        // Keep the cache coherent so the UI reflects the new value immediately.
        _cachedLocale = locale;
      }
      return result;
    } catch (e) {
      return LanguageSetResult(ok: false, reason: 'exception: $e');
    }
  }

  @override
  Future<LanguageSetResult> setClusterLanguage(Locale locale) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'setClusterLanguage',
        {'languageTag': _toLanguageTag(locale)},
      );
      return _parseResult(raw);
    } catch (e) {
      return LanguageSetResult(ok: false, reason: 'exception: $e');
    }
  }

  @override
  Future<bool> clusterSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('clusterSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert [Locale] to a BCP-47 language tag string for the native side.
  /// e.g. Locale('en') → "en", Locale('ru') → "ru", Locale('zh','CN') → "zh-CN"
  static String _toLanguageTag(Locale locale) {
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '${locale.languageCode}-${locale.countryCode}';
    }
    return locale.languageCode;
  }

  /// Parse a locale tag string back to a [Locale].
  static Locale _parseLocaleTag(String tag) {
    // Handles "en", "en-US", "en_US", "ru", "ru-RU", "zh-Hans-CN"
    final parts = tag.replaceAll('_', '-').split('-');
    if (parts.length >= 2) {
      return Locale(parts[0].toLowerCase(), parts[1].toUpperCase());
    }
    return Locale(parts[0].toLowerCase());
  }

  /// Parse the {ok, reason} map returned by the Kotlin handler.
  static LanguageSetResult _parseResult(Map<String, Object?>? raw) {
    if (raw == null) return const LanguageSetResult(ok: false, reason: 'null-response');
    final ok = raw['ok'] as bool? ?? false;
    final reason = raw['reason'] as String?;
    return LanguageSetResult(ok: ok, reason: reason);
  }
}

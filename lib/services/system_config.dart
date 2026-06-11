import 'dart:ui' show Locale;

/// System locale and language configuration port.
/// Reads the platform-reported locale; writes user overrides for both the
/// cluster display and the main app language.
abstract class SystemConfig {
  Locale get systemLocale;
  Future<void> setSystemLanguage(Locale l);
  Future<void> setClusterLanguage(Locale l);
}

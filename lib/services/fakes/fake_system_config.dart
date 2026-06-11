import 'dart:ui' show Locale;

import '../system_config.dart';

/// T1 fake for [SystemConfig].
/// In-memory; system locale defaults to the platform locale on construction.
class FakeSystemConfig implements SystemConfig {
  FakeSystemConfig([Locale? initial])
      : _systemLocale = initial ?? const Locale('en');

  final Locale _systemLocale;
  Locale? _appLocale;
  Locale? _clusterLocale;

  @override
  Locale get systemLocale => _systemLocale;

  Locale get effectiveAppLocale => _appLocale ?? _systemLocale;
  Locale get effectiveClusterLocale => _clusterLocale ?? _systemLocale;

  @override
  Future<void> setSystemLanguage(Locale l) async => _appLocale = l;

  @override
  Future<void> setClusterLanguage(Locale l) async => _clusterLocale = l;
}

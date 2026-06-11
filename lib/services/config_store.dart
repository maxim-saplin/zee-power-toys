import 'dart:convert';

/// Minimal app configuration — one field for now.
/// Plain JSON serialization so the native boot shim can read it.
class AppConfig {
  const AppConfig({this.hudBoxOn = false});

  final bool hudBoxOn;

  AppConfig copyWith({bool? hudBoxOn}) =>
      AppConfig(hudBoxOn: hudBoxOn ?? this.hudBoxOn);

  Map<String, Object?> toJson() => <String, Object?>{'hudBoxOn': hudBoxOn};

  factory AppConfig.fromJson(Map<String, Object?> json) =>
      AppConfig(hudBoxOn: json['hudBoxOn'] as bool? ?? false);

  /// Convenience: round-trip through JSON string (used by SharedPrefsConfigStore).
  factory AppConfig.fromJsonString(String s) =>
      AppConfig.fromJson(jsonDecode(s) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      other is AppConfig && other.hudBoxOn == hudBoxOn;

  @override
  int get hashCode => hudBoxOn.hashCode;
}

/// Port for config persistence. Each isolate owns its own instance.
abstract class ConfigStore {
  AppConfig get value;
  Stream<AppConfig> get changes;
  Future<void> load();
  Future<void> setConfig(AppConfig next);
}

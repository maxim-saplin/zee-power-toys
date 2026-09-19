import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config_store.dart';

// SharedPreferences key — plain string JSON so the native boot shim can read it.
const String _kPrefKey = 'zee.config';

/// Bumped when we must rewrite persisted minimap fields for existing installs.
/// v3 (2026-09-19): White/3.0/150, advanced=false, contentScale=0.5 (phase0 density).
const String _kSchemaKey = 'zee.config.schema';
const int _kSchemaVersion = 3;

/// SharedPreferences-backed ConfigStore.
/// The whole AppConfig is stored as one JSON string under [_kPrefKey].
/// This is native-readable on Android (XML SharedPreferences) per ADR 0003.
class SharedPrefsConfigStore implements ConfigStore {
  SharedPrefsConfigStore() : _ctrl = StreamController<AppConfig>.broadcast();

  final StreamController<AppConfig> _ctrl;
  AppConfig _value = const AppConfig();

  @override
  AppConfig get value => _value;

  @override
  Stream<AppConfig> get changes => _ctrl.stream;

  @override
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    if (raw != null) {
      try {
        _value = AppConfig.fromJsonString(raw);
      } catch (_) {
        // Corrupted prefs: start fresh.
        _value = const AppConfig();
      }
    }
    final schema = prefs.getInt(_kSchemaKey) ?? 0;
    if (schema < _kSchemaVersion) {
      _value = _migrateMinimapPhase0(_value);
      await prefs.setString(_kPrefKey, jsonEncode(_value.toJson()));
      await prefs.setInt(_kSchemaKey, _kSchemaVersion);
    }
  }

  /// One-shot car/desktop migration: unlock presets + phase0 White look.
  static AppConfig _migrateMinimapPhase0(AppConfig cfg) {
    final mm = cfg.minimap;
    return cfg.copyWith(
      minimap: mm.copyWith(
        advanced: false,
        contentScale: 0.5,
        looks: const MinimapLooks(
          colorPreset: 'white',
          contrast: 3.0,
          threshold: 150.0,
        ),
      ),
    );
  }

  @override
  Future<void> setConfig(AppConfig next) async {
    _value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(next.toJson()));
    // Keep schema current so we do not re-migrate user tweaks after v2.
    await prefs.setInt(_kSchemaKey, _kSchemaVersion);
    _ctrl.add(next);
  }
}

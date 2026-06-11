import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config_store.dart';

// SharedPreferences key — plain string JSON so the native boot shim can read it.
const String _kPrefKey = 'zee.config';

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
  }

  @override
  Future<void> setConfig(AppConfig next) async {
    _value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(next.toJson()));
    _ctrl.add(next);
  }
}

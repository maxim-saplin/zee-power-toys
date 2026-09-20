import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_store.dart';
import 'durable_store_paths.dart';

// SharedPreferences key — plain string JSON so the native boot shim can read it.
const String kZeeConfigPrefKey = 'zee.config';

/// Bumped when we must rewrite persisted minimap fields for existing installs.
/// v4 (2026-09-19): phase0 Default look (huePass 1 / hueAngle 290), contentScale 0.5.
const String _kSchemaKey = 'zee.config.schema';
const int _kSchemaVersion = 4;

/// SharedPreferences-backed ConfigStore with a **durable file mirror**.
///
/// Primary: SharedPreferences (`flutter.zee.config`) for ADR 0003 boot shim.
/// Mirror: `/sdcard/zee-power-toys/config.json` (Android) so prefs survive
/// `adb uninstall` forced by SHARED_USER_INCOMPATIBLE / signing flips (0054).
class SharedPrefsConfigStore implements ConfigStore {
  SharedPrefsConfigStore({File? durableMirror})
      : _ctrl = StreamController<AppConfig>.broadcast(),
        _durableOverride = durableMirror;

  final StreamController<AppConfig> _ctrl;
  final File? _durableOverride;
  AppConfig _value = const AppConfig();

  @override
  AppConfig get value => _value;

  @override
  Stream<AppConfig> get changes => _ctrl.stream;

  Future<File> _mirrorFile() async =>
      _durableOverride ?? await durableConfigFile();

  @override
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kZeeConfigPrefKey);
    var fromPrefs = false;
    if (raw != null) {
      try {
        _value = AppConfig.fromJsonString(raw);
        fromPrefs = true;
      } catch (_) {
        _value = const AppConfig();
      }
    }

    // Prefs empty/corrupt after reinstall → restore durable mirror if present.
    if (!fromPrefs) {
      try {
        final mirror = await _mirrorFile();
        if (await mirror.exists()) {
          final mirrored = await mirror.readAsString();
          _value = AppConfig.fromJsonString(mirrored);
          await prefs.setString(kZeeConfigPrefKey, mirrored);
          debugPrint('config: restored from durable mirror ${mirror.path}');
        }
      } catch (e) {
        debugPrint('config: durable restore failed: $e');
      }
    }

    final schema = prefs.getInt(_kSchemaKey) ?? 0;
    if (schema < _kSchemaVersion) {
      _value = _migrateMinimapPhase0(_value);
      await prefs.setString(kZeeConfigPrefKey, jsonEncode(_value.toJson()));
      await prefs.setInt(_kSchemaKey, _kSchemaVersion);
    }

    // Always refresh mirror so pack/settings survive the next wipe.
    await _writeMirror(_value);
  }

  /// One-shot car/desktop migration: unlock presets + phase0 White look.
  static AppConfig _migrateMinimapPhase0(AppConfig cfg) {
    final mm = cfg.minimap;
    return cfg.copyWith(
      minimap: mm.copyWith(
        advanced: false,
        contentScale: 0.5,
        looks: MinimapLooks.bundle('default'),
      ),
    );
  }

  Future<void> _writeMirror(AppConfig cfg) async {
    try {
      final mirror = await _mirrorFile();
      final parent = mirror.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await mirror.writeAsString(jsonEncode(cfg.toJson()), flush: true);
    } catch (e) {
      debugPrint('config: durable mirror write failed: $e');
    }
  }

  @override
  Future<void> setConfig(AppConfig next) async {
    _value = next;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(next.toJson());
    await prefs.setString(kZeeConfigPrefKey, encoded);
    // Keep schema current so we do not re-migrate user tweaks after v2.
    await prefs.setInt(_kSchemaKey, _kSchemaVersion);
    await _writeMirror(next);
    _ctrl.add(next);
  }
}

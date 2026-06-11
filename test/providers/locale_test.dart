import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/providers/config.dart';
import 'package:zee_power_toys/providers/locale.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory ProviderContainer with a SharedPrefs-backed ConfigStore
/// seeded with [initial].
Future<(ProviderContainer, ConfigStore)> _makeContainer(AppConfig initial) async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  await store.setConfig(initial);

  final container = ProviderContainer(
    overrides: [configStoreProvider.overrideWithValue(store)],
  );
  // Activate the stream provider so the Riverpod graph stays live.
  container.listen(appConfigProvider, (prev, next) {});
  addTearDown(container.dispose);
  return (container, store);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('appLocaleProvider — locale resolution', () {
    test('returns null when no override (follow system)', () async {
      final (container, _) = await _makeContainer(const AppConfig());
      expect(container.read(appLocaleProvider), isNull);
    });

    test('returns Locale("en") for override="en"', () async {
      final (container, _) =
          await _makeContainer(const AppConfig(locale: 'en'));
      expect(container.read(appLocaleProvider), equals(const Locale('en')));
    });

    test('returns Locale("ru") for override="ru"', () async {
      final (container, _) =
          await _makeContainer(const AppConfig(locale: 'ru'));
      expect(container.read(appLocaleProvider), equals(const Locale('ru')));
    });

    test('returns null for unknown locale code (falls back to system)', () async {
      final (container, _) =
          await _makeContainer(const AppConfig(locale: 'fr'));
      expect(container.read(appLocaleProvider), isNull);
    });

    test('en override takes priority over null (system)', () async {
      final (container, store) = await _makeContainer(const AppConfig());
      expect(container.read(appLocaleProvider), isNull);

      // Set override via the store; wait for the stream to propagate.
      await store.setConfig(store.value.copyWith(locale: 'en'));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appLocaleProvider), equals(const Locale('en')));
    });

    test('clearing override (null) reverts to system', () async {
      final (container, store) =
          await _makeContainer(const AppConfig(locale: 'ru'));
      expect(container.read(appLocaleProvider), equals(const Locale('ru')));

      await store.setConfig(store.value.copyWith(locale: null));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appLocaleProvider), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig.locale JSON round-trip
  // ---------------------------------------------------------------------------

  group('AppConfig.locale JSON round-trip', () {
    test('null locale is omitted from toJson', () {
      final json = const AppConfig().toJson();
      expect(json.containsKey('locale'), isFalse);
    });

    test('locale="en" survives toJson → fromJson', () {
      const cfg = AppConfig(locale: 'en');
      final rt = AppConfig.fromJson(cfg.toJson());
      expect(rt.locale, equals('en'));
    });

    test('locale="ru" survives toJson → fromJson', () {
      const cfg = AppConfig(locale: 'ru');
      final rt = AppConfig.fromJson(cfg.toJson());
      expect(rt.locale, equals('ru'));
    });

    test('fromJson without locale key returns null', () {
      final cfg = AppConfig.fromJson(<String, Object?>{'hudBoxOn': false});
      expect(cfg.locale, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig.copyWith locale sentinel
  // ---------------------------------------------------------------------------

  group('AppConfig.copyWith locale sentinel', () {
    test('omitting locale preserves the existing value', () {
      const cfg = AppConfig(locale: 'ru');
      final copy = cfg.copyWith(hudBoxOn: true);
      expect(copy.locale, equals('ru'));
    });

    test('passing locale=null clears the override', () {
      const cfg = AppConfig(locale: 'ru');
      final copy = cfg.copyWith(locale: null);
      expect(copy.locale, isNull);
    });

    test('passing locale="en" sets override', () {
      const cfg = AppConfig();
      final copy = cfg.copyWith(locale: 'en');
      expect(copy.locale, equals('en'));
    });
  });

  // ---------------------------------------------------------------------------
  // ARB parity — both locale files must have identical non-meta key sets
  // ---------------------------------------------------------------------------

  group('ARB parity', () {
    test('app_en.arb and app_ru.arb have identical key sets', () {
      final enKeys = _arbKeys('lib/l10n/app_en.arb');
      final ruKeys = _arbKeys('lib/l10n/app_ru.arb');

      final missingInRu = enKeys.difference(ruKeys);
      final extraInRu = ruKeys.difference(enKeys);

      expect(
        missingInRu,
        isEmpty,
        reason: 'Keys in app_en.arb missing from app_ru.arb: $missingInRu',
      );
      expect(
        extraInRu,
        isEmpty,
        reason: 'Extra keys in app_ru.arb not in app_en.arb: $extraInRu',
      );
    });
  });
}

/// Read ARB translation keys (excluding @-prefixed metadata entries).
Set<String> _arbKeys(String path) {
  final raw = File(path).readAsStringSync();
  final map = jsonDecode(raw) as Map<String, Object?>;
  return map.keys.where((k) => !k.startsWith('@')).toSet();
}

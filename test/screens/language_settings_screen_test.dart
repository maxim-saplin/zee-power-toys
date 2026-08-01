import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/language_settings_screen.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

// ---------------------------------------------------------------------------
// Block 0015 tests
//
// Three groups:
//   1. SystemConfig adapter contract via FakeSystemConfig.
//   2. LanguageSettingsScreen shows 3 sections (App / System / Cluster).
//   3. System/Cluster pickers are disabled when FakeSystemConfig is unsupported.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget child,
  ConfigStore store,
  FakeSystemConfig sysConfig,
) =>
    wrapWithProviders(child, store: store, systemConfig: sysConfig);

Future<SharedPrefsConfigStore> _makeStore([
  AppConfig cfg = const AppConfig(),
]) async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  await store.setConfig(cfg);
  return store;
}

// ---------------------------------------------------------------------------
// 1. SystemConfig adapter contract via FakeSystemConfig
// ---------------------------------------------------------------------------

void main() {
  group('SystemConfig adapter contract (FakeSystemConfig)', () {
    test('systemLocale returns initial locale', () {
      final cfg = FakeSystemConfig(initial: const Locale('ru'));
      expect(cfg.systemLocale, equals(const Locale('ru')));
    });

    test('setSystemLanguage → ok when not unsupported', () async {
      final cfg = FakeSystemConfig();
      final result = await cfg.setSystemLanguage(const Locale('ru'));
      expect(result.ok, isTrue);
      expect(cfg.lastSystemLanguage, equals(const Locale('ru')));
      expect(cfg.systemLocale, equals(const Locale('ru')));
    });

    test('setClusterLanguage → ok when not unsupported', () async {
      final cfg = FakeSystemConfig();
      final result = await cfg.setClusterLanguage(const Locale('ru'));
      expect(result.ok, isTrue);
      expect(cfg.lastClusterLanguage, equals(const Locale('ru')));
    });

    test('clusterSupported → true when not unsupported', () async {
      final cfg = FakeSystemConfig();
      expect(await cfg.clusterSupported(), isTrue);
    });

    test('setSystemLanguage → unsupported-on-device when unsupported=true', () async {
      final cfg = FakeSystemConfig(unsupported: true);
      final result = await cfg.setSystemLanguage(const Locale('ru'));
      expect(result.ok, isFalse);
      expect(result.reason, equals('unsupported-on-device'));
    });

    test('setClusterLanguage → unsupported-on-device when unsupported=true', () async {
      final cfg = FakeSystemConfig(unsupported: true);
      final result = await cfg.setClusterLanguage(const Locale('ru'));
      expect(result.ok, isFalse);
      expect(result.reason, equals('unsupported-on-device'));
    });

    test('clusterSupported → false when unsupported=true', () async {
      final cfg = FakeSystemConfig(unsupported: true);
      expect(await cfg.clusterSupported(), isFalse);
    });

    test('systemLocale unchanged after unsupported setSystemLanguage', () async {
      final cfg = FakeSystemConfig(
        initial: const Locale('en'),
        unsupported: true,
      );
      await cfg.setSystemLanguage(const Locale('ru'));
      // Unsupported fake must NOT mutate the locale on failure.
      expect(cfg.systemLocale, equals(const Locale('en')));
    });
  });

  // -------------------------------------------------------------------------
  // 2. LanguageSettingsScreen shows 3 sections
  // -------------------------------------------------------------------------

  group('LanguageSettingsScreen — 3 sections visible', () {
    testWidgets('shows App / System / Cluster section headings', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      // Allow the async clusterSupported() call to resolve.
      await tester.pumpAndSettle();

      // All three section headings must appear.
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('System language'), findsOneWidget);
      expect(find.text('Cluster language'), findsOneWidget);
    });

    testWidgets('App section has System default / English / Russian', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      expect(find.text('System default'), findsWidgets);
      expect(find.byKey(const ValueKey('lang-system')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang-ru')), findsOneWidget);
    });

    testWidgets('tapping English in App section sets locale=en in store', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('lang-en')));
      await tester.pump();
      expect(store.value.locale, equals('en'));
    });

    testWidgets('tapping Russian in App section sets locale=ru in store', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('lang-ru')));
      await tester.pump();
      expect(store.value.locale, equals('ru'));
    });

    testWidgets('System section EN and RU pickers are present', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sys-lang-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('sys-lang-ru')), findsOneWidget);
    });

    testWidgets('Cluster section EN and RU pickers are present', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cluster-lang-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('cluster-lang-ru')), findsOneWidget);
    });

    testWidgets('selecting System EN calls setSystemLanguage on FakeSystemConfig', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('ru'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sys-lang-en')));
      await tester.pumpAndSettle();

      expect(sysConfig.lastSystemLanguage, equals(const Locale('en')));
    });

    testWidgets('selecting Cluster RU calls setClusterLanguage on FakeSystemConfig', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(initial: const Locale('en'));
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      // The Cluster section may be below the fold — scroll to it before tapping.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cluster-lang-ru')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cluster-lang-ru')));
      await tester.pumpAndSettle();

      expect(sysConfig.lastClusterLanguage, equals(const Locale('ru')));
    });
  });

  // -------------------------------------------------------------------------
  // 3. System/Cluster disabled when FakeSystemConfig is unsupported
  // -------------------------------------------------------------------------

  group('LanguageSettingsScreen — disabled when unsupported', () {
    testWidgets('shows car-only hint for System section when unsupported', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(unsupported: true);
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      // The localized car-only hint must appear (at least once, may be twice
      // since both System and Cluster sections show it).
      expect(find.text('Available on the car only'), findsWidgets);
    });

    testWidgets('System picker does not call setSystemLanguage when unsupported', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(unsupported: true);
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sys-lang-ru')));
      await tester.pumpAndSettle();

      // No call should have been made to setSystemLanguage.
      expect(sysConfig.lastSystemLanguage, isNull);
    });

    testWidgets('Cluster picker does not call setClusterLanguage when unsupported', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(unsupported: true);
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      // Scroll to ensure the cluster section is visible.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cluster-lang-ru')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cluster-lang-ru')));
      await tester.pumpAndSettle();

      // No call should have been made to setClusterLanguage.
      expect(sysConfig.lastClusterLanguage, isNull);
    });

    testWidgets('App language picker still works when system/cluster unsupported', (tester) async {
      final store = await _makeStore();
      final sysConfig = FakeSystemConfig(unsupported: true);
      await tester.pumpWidget(
        _wrap(const LanguageSettingsScreen(), store, sysConfig),
      );
      await tester.pumpAndSettle();

      // App picker must still work even when system/cluster are disabled.
      await tester.tap(find.byKey(const ValueKey('lang-ru')));
      await tester.pump();
      expect(store.value.locale, equals('ru'));
    });
  });
}

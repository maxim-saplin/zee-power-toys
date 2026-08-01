import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/settings_home_screen.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Full-service wrapper needed because navigating to HudSettingsScreen
/// renders HudPreview which subscribes to carSignals/config providers.
Widget _wrap(Widget child, ConfigStore store) => wrapWithProviders(child, store: store);

Future<SharedPrefsConfigStore> _makeStore([AppConfig cfg = const AppConfig()]) async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  await store.setConfig(cfg);
  return store;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsHomeScreen', () {
    testWidgets('renders four section tiles', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      // All four section titles appear (English default).
      expect(find.text('HUD'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('HUD tile navigates to HudSettingsScreen', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      await tester.tap(find.text('HUD'));
      // Not pumpAndSettle(): HudSettingsScreen's Config Preview (Block 0026)
      // forces the blinker into a perpetually-repeating blink animation, which
      // never settles. Pump past the route-push transition instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // HudSettingsScreen appbar title appears.
      expect(find.text('HUD Settings'), findsOneWidget);
    });
  });

  group('Language picker', () {
    testWidgets('shows App language options (System default, EN, RU)', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      // Navigate to Language — now routes to LanguageSettingsScreen (Block 0015).
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // The new screen has 3 sections; App picker keys are still lang-system/en/ru.
      // 'System default' appears once (only the App section has it).
      expect(find.text('System default'), findsOneWidget);
      // 'English' and 'Русский' appear multiple times (App + System + Cluster sections).
      expect(find.text('English'), findsWidgets);
      expect(find.text('Русский'), findsWidgets);
      // App-language picker keys are present.
      expect(find.byKey(const ValueKey('lang-system')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang-ru')), findsOneWidget);
    });

    testWidgets('tapping English sets locale=en in ConfigStore', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // Tap the English radio via its ValueKey.
      await tester.tap(find.byKey(const ValueKey('lang-en')));
      await tester.pump();

      expect(store.value.locale, equals('en'));
    });

    testWidgets('tapping Russian sets locale=ru in ConfigStore', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('lang-ru')));
      await tester.pump();

      expect(store.value.locale, equals('ru'));
    });

    testWidgets('tapping System default sets locale=null', (tester) async {
      final store = await _makeStore(const AppConfig(locale: 'ru'));
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('lang-system')));
      await tester.pump();

      expect(store.value.locale, isNull);
    });
  });
}

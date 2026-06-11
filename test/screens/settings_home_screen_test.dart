import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/screens/settings_home_screen.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Full-service wrapper needed because navigating to HudSettingsScreen
/// renders HudPreview which subscribes to carSignals/config providers.
Widget _wrap(Widget child, ConfigStore store) => ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

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
      await tester.pumpAndSettle();

      // HudSettingsScreen appbar title appears.
      expect(find.text('HUD Settings'), findsOneWidget);
    });
  });

  group('Language picker', () {
    testWidgets('shows all three options', (tester) async {
      final store = await _makeStore();
      await tester.pumpWidget(_wrap(const SettingsHomeScreen(), store));
      await tester.pump();

      // Navigate to Language.
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(find.text('System default'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
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

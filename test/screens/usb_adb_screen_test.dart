import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/providers/usb_mode.dart';
import 'package:zee_power_toys/screens/usb_adb_screen.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/fakes/fake_usb_mode.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';
import 'package:zee_power_toys/services/usb_mode.dart';

// ---------------------------------------------------------------------------
// Block 0016 / 0023 tests
//
// Three groups:
//   1. UsbMode mapping: peripheral↔"0" / host↔"1" via FakeUsbMode.
//   2. UsbAdbScreen shows USB/ADB section; SegmentedButton works on T1.
//      (QA2-2: screen moved from DiagnosticsScreen to dedicated hub tile.)
//   3. UsbAdbScreen shows disabled hint when FakeUsbMode.unsupported=true.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, ConfigStore store, FakeUsbMode usbMode) =>
    ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
        usbModeProvider.overrideWithValue(usbMode),
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

Future<SharedPrefsConfigStore> _makeStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  return store;
}

// ---------------------------------------------------------------------------
// 1. UsbMode mapping (FakeUsbMode)
// ---------------------------------------------------------------------------

void main() {
  group('UsbMode mapping via FakeUsbMode', () {
    test('peripheral → getRawUsbMode returns "0"', () async {
      final fake = FakeUsbMode(initialMode: UsbMode.peripheral);
      expect(await fake.getRawUsbMode(), equals('0'));
    });

    test('host → getRawUsbMode returns "1"', () async {
      final fake = FakeUsbMode(initialMode: UsbMode.host);
      expect(await fake.getRawUsbMode(), equals('1'));
    });

    test('auto → getRawUsbMode returns "0" (peripheral forced on boot)', () async {
      final fake = FakeUsbMode(initialMode: UsbMode.auto);
      expect(await fake.getRawUsbMode(), equals('0'));
    });

    test('setUsbMode(peripheral) → ok; currentMode=peripheral', () async {
      final fake = FakeUsbMode();
      final result = await fake.setUsbMode(UsbMode.peripheral);
      expect(result.ok, isTrue);
      expect(fake.currentMode, equals(UsbMode.peripheral));
      expect(fake.lastSetMode, equals(UsbMode.peripheral));
    });

    test('setUsbMode(host) → ok; currentMode=host', () async {
      final fake = FakeUsbMode();
      final result = await fake.setUsbMode(UsbMode.host);
      expect(result.ok, isTrue);
      expect(fake.currentMode, equals(UsbMode.host));
    });

    test('setUsbMode(auto) → ok; currentMode=auto', () async {
      final fake = FakeUsbMode();
      final result = await fake.setUsbMode(UsbMode.auto);
      expect(result.ok, isTrue);
      expect(fake.currentMode, equals(UsbMode.auto));
    });

    test('unsupported: setUsbMode returns requires-platform-signing', () async {
      final fake = FakeUsbMode(unsupported: true);
      final result = await fake.setUsbMode(UsbMode.host);
      expect(result.ok, isFalse);
      expect(result.reason, equals('requires-platform-signing'));
    });

    test('unsupported: currentMode stays at initial value', () async {
      final fake = FakeUsbMode(
        initialMode: UsbMode.peripheral,
        unsupported: true,
      );
      await fake.setUsbMode(UsbMode.host);
      expect(fake.currentMode, equals(UsbMode.peripheral));
    });

    test('unsupported: writable=false', () {
      expect(FakeUsbMode(unsupported: true).writable, isFalse);
    });

    test('supported: writable=true', () {
      expect(FakeUsbMode().writable, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 2. UsbAdbScreen shows USB/ADB section; SegmentedButton works on T1
  // -------------------------------------------------------------------------

  group('UsbAdbScreen USB/ADB section — writable T1', () {
    testWidgets('USB/ADB section heading is visible', (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode();
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      // Peripheral button should be immediately visible (no scroll needed on this
      // dedicated screen). Verify USB / ADB heading and the segment labels.
      expect(find.text('USB / ADB'), findsWidgets);
    });

    testWidgets('SegmentedButton with Peripheral, Host, Auto is visible',
        (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode();
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      expect(find.text('Peripheral'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('tapping Host segment sets UsbMode.host via FakeUsbMode',
        (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode(initialMode: UsbMode.peripheral);
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Host'));
      await tester.pumpAndSettle();

      expect(usbMode.lastSetMode, equals(UsbMode.host));
    });

    testWidgets('tapping Auto segment sets UsbMode.auto via FakeUsbMode',
        (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode();
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();

      expect(usbMode.lastSetMode, equals(UsbMode.auto));
    });

    testWidgets('current mode "Current: Peripheral" is shown', (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode(initialMode: UsbMode.peripheral);
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      expect(find.textContaining('Current:'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Disabled hint when unsupported
  // -------------------------------------------------------------------------

  group('UsbAdbScreen USB/ADB — disabled when unsupported', () {
    testWidgets('shows platform-signing-required hint when unsupported',
        (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode(unsupported: true);
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      expect(
        find.text('Requires platform signing — available on the car'),
        findsOneWidget,
      );
    });

    testWidgets('SegmentedButton does not call setUsbMode when unsupported',
        (tester) async {
      final store = await _makeStore();
      final usbMode = FakeUsbMode(unsupported: true);
      await tester.pumpWidget(_wrap(const UsbAdbScreen(), store, usbMode));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Host'));
      await tester.pumpAndSettle();

      // Unsupported fake: lastSetMode must remain null (no call made).
      expect(usbMode.lastSetMode, isNull);
    });
  });
}

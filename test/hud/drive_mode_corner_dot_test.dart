import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/drive_mode_corner_dot.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

Finder _dot(DriveMode mode) =>
    find.byKey(ValueKey('drive-mode-corner-dot-${mode.name}'));

Future<void> _emitMode(WidgetTester tester, FakeCarSignals signals, DriveMode mode) async {
  signals.emitDriveMode(mode);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(useMockPrefs);

  test('0110 corner-dot accents: Comfort blue / ECO green / Sport yellow', () {
    expect(driveModeCornerDotColor(DriveMode.eco), const Color(0xFF3DDC84));
    expect(
      driveModeCornerDotColor(DriveMode.comfort),
      const Color(0xFF3B82F6),
    );
    expect(driveModeCornerDotColor(DriveMode.sport), const Color(0xFFFFCC00));
    expect(driveModeCornerDotColor(DriveMode.other), isNull);
    expect(driveModeCornerDotColor(DriveMode.unknown), isNull);

    // Sport persistent ≠ toast Sport red (0109).
    expect(
      driveModeCornerDotColor(DriveMode.sport),
      isNot(const Color(0xFFFF3B30)),
    );
  });

  group('BatteryConfig.showDriveModeCornerDot', () {
    test('defaults false and persists', () {
      const c = BatteryConfig();
      expect(c.showDriveModeCornerDot, isFalse);
      final on = c.copyWith(showDriveModeCornerDot: true);
      expect(on.showDriveModeCornerDot, isTrue);
      expect(
        BatteryConfig.fromJson(on.toJson()).showDriveModeCornerDot,
        isTrue,
      );
      expect(
        BatteryConfig.fromJson(const {}).showDriveModeCornerDot,
        isFalse,
      );
    });
  });

  group('HUD corner dot', () {
    testWidgets('OFF → no dot even with known mode', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 800, height: 480, child: HudRoot()),
        signals: signals,
        localizations: false,
        config: const AppConfig(
          battery: BatteryConfig(showDriveModeCornerDot: false),
        ),
      ));
      await tester.pump();
      await _emitMode(tester, signals, DriveMode.comfort);
      expect(_dot(DriveMode.comfort), findsNothing);
      expect(_dot(DriveMode.eco), findsNothing);
      expect(_dot(DriveMode.sport), findsNothing);
    });

    testWidgets('ON + known mode → BR colored dot; live updates; unknown hides',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 800, height: 480, child: HudRoot()),
        signals: signals,
        localizations: false,
        config: const AppConfig(
          battery: BatteryConfig(showDriveModeCornerDot: true),
        ),
      ));
      await tester.pump();

      // Cold unknown → hide.
      expect(_dot(DriveMode.comfort), findsNothing);

      await _emitMode(tester, signals, DriveMode.comfort);
      expect(_dot(DriveMode.comfort), findsOneWidget);
      final comfortDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.comfort)).decoration as BoxDecoration;
      expect(comfortDeco.color, const Color(0xFF3B82F6));
      expect(comfortDeco.shape, BoxShape.circle);

      await _emitMode(tester, signals, DriveMode.eco);
      expect(_dot(DriveMode.comfort), findsNothing);
      expect(_dot(DriveMode.eco), findsOneWidget);
      final ecoDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.eco)).decoration as BoxDecoration;
      expect(ecoDeco.color, const Color(0xFF3DDC84));

      await _emitMode(tester, signals, DriveMode.sport);
      expect(_dot(DriveMode.sport), findsOneWidget);
      final sportDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.sport)).decoration as BoxDecoration;
      expect(sportDeco.color, const Color(0xFFFFCC00));

      await _emitMode(tester, signals, DriveMode.unknown);
      expect(_dot(DriveMode.sport), findsNothing);
      expect(_dot(DriveMode.eco), findsNothing);

      await _emitMode(tester, signals, DriveMode.other);
      expect(_dot(DriveMode.comfort), findsNothing);
    });

    testWidgets('toggle OFF at runtime removes dot', (tester) async {
      final signals = FakeCarSignals();
      final store = SharedPrefsConfigStore();
      await store.setConfig(const AppConfig(
        battery: BatteryConfig(showDriveModeCornerDot: true),
      ));

      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 800, height: 480, child: HudRoot()),
        signals: signals,
        store: store,
        localizations: false,
      ));
      await tester.pump();

      await _emitMode(tester, signals, DriveMode.sport);
      expect(_dot(DriveMode.sport), findsOneWidget);

      await store.setConfig(store.value.copyWith(
        battery: store.value.battery.copyWith(showDriveModeCornerDot: false),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_dot(DriveMode.sport), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HudRoot)),
      );
      expect(
        container.read(configStoreProvider).value.battery.showDriveModeCornerDot,
        isFalse,
      );
    });
  });
}

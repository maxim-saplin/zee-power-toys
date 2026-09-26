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

Opacity _opacityOf(WidgetTester tester, DriveMode mode) {
  return tester.widget<Opacity>(
    find.byKey(ValueKey('drive-mode-corner-dot-opacity-${mode.name}')),
  );
}

Transform _scaleOf(WidgetTester tester, DriveMode mode) {
  return tester.widget<Transform>(
    find.byKey(ValueKey('drive-mode-corner-dot-scale-${mode.name}')),
  );
}

/// X-axis scale from [Transform.scale] (Z stays 1.0 so getMaxScaleOnAxis is wrong).
double _scaleX(Transform t) => t.transform.storage[0];

void main() {
  setUp(useMockPrefs);

  test('0112 corner-dot accents: ECO blue / Comfort green / Sport red', () {
    expect(driveModeCornerDotColor(DriveMode.eco), const Color(0xFF3B82F6));
    expect(
      driveModeCornerDotColor(DriveMode.comfort),
      const Color(0xFF3DDC84),
    );
    expect(driveModeCornerDotColor(DriveMode.sport), const Color(0xFFFF3B30));
    expect(driveModeCornerDotColor(DriveMode.other), isNull);
    expect(driveModeCornerDotColor(DriveMode.unknown), isNull);

    // Sport persistent == toast Sport red (0112); yellow dropped.
    expect(
      driveModeCornerDotColor(DriveMode.sport),
      isNot(const Color(0xFFFFCC00)),
    );
  });

  group('0113 Sport pulse math', () {
    test('period is gentle 1600 ms (~0.625 Hz)', () {
      expect(
        DriveModeCornerDotLayer.kSportPulsePeriod,
        const Duration(milliseconds: 1600),
      );
      // Seizure-risk floor is typically ~3 Hz (period < ~333 ms) — stay well above.
      expect(
        DriveModeCornerDotLayer.kSportPulsePeriod.inMilliseconds,
        greaterThanOrEqualTo(1000),
      );
    });

    test('sportPulseIntensity sine breath: 0 → 1 → 0 over cycle', () {
      expect(sportPulseIntensity(0.0), closeTo(0.0, 1e-9));
      expect(sportPulseIntensity(0.25), closeTo(0.5, 1e-9));
      expect(sportPulseIntensity(0.5), closeTo(1.0, 1e-9));
      expect(sportPulseIntensity(0.75), closeTo(0.5, 1e-9));
      expect(sportPulseIntensity(1.0), closeTo(0.0, 1e-9));
      // wraps
      expect(sportPulseIntensity(1.5), closeTo(1.0, 1e-9));
    });

    test('opacity/scale map intensity; calm constants fixed', () {
      expect(sportPulseOpacity(0.0), DriveModeCornerDotLayer.kSportPulseOpacityMin);
      expect(sportPulseOpacity(1.0), 1.0);
      expect(sportPulseOpacity(0.5), closeTo(0.71, 0.01));

      expect(sportPulseScale(0.0), DriveModeCornerDotLayer.kSportPulseScaleMin);
      expect(sportPulseScale(1.0), DriveModeCornerDotLayer.kSportPulseScaleMax);
    });
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
      expect(_dot(DriveMode.eco), findsNothing);

      // ECO → Comfort → Sport order (0112).
      await _emitMode(tester, signals, DriveMode.eco);
      expect(_dot(DriveMode.eco), findsOneWidget);
      final ecoDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.eco)).decoration as BoxDecoration;
      expect(ecoDeco.color, const Color(0xFF3B82F6));
      expect(ecoDeco.shape, BoxShape.circle);
      // 0113: ECO calm — opacity/size fixed.
      expect(_opacityOf(tester, DriveMode.eco).opacity, 1.0);
      expect(_scaleX(_scaleOf(tester, DriveMode.eco)), 1.0);

      await _emitMode(tester, signals, DriveMode.comfort);
      expect(_dot(DriveMode.eco), findsNothing);
      expect(_dot(DriveMode.comfort), findsOneWidget);
      final comfortDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.comfort)).decoration as BoxDecoration;
      expect(comfortDeco.color, const Color(0xFF3DDC84));
      expect(_opacityOf(tester, DriveMode.comfort).opacity, 1.0);

      await _emitMode(tester, signals, DriveMode.sport);
      expect(_dot(DriveMode.sport), findsOneWidget);
      final sportDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.sport)).decoration as BoxDecoration;
      expect(sportDeco.color, const Color(0xFFFF3B30));

      await _emitMode(tester, signals, DriveMode.unknown);
      expect(_dot(DriveMode.sport), findsNothing);
      expect(_dot(DriveMode.eco), findsNothing);

      await _emitMode(tester, signals, DriveMode.other);
      expect(_dot(DriveMode.comfort), findsNothing);
    });

    testWidgets('0113 ON + Sport → opacity/scale pulse; ECO/Comfort stay calm',
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

      // ECO calm across half a Sport period.
      await _emitMode(tester, signals, DriveMode.eco);
      final ecoOp0 = _opacityOf(tester, DriveMode.eco).opacity;
      final ecoSc0 =
          _scaleX(_scaleOf(tester, DriveMode.eco));
      await tester.pump(const Duration(milliseconds: 800));
      expect(_opacityOf(tester, DriveMode.eco).opacity, ecoOp0);
      expect(
        _scaleX(_scaleOf(tester, DriveMode.eco)),
        ecoSc0,
      );
      expect(ecoOp0, 1.0);
      expect(ecoSc0, 1.0);

      // Comfort calm.
      await _emitMode(tester, signals, DriveMode.comfort);
      await tester.pump(const Duration(milliseconds: 800));
      expect(_opacityOf(tester, DriveMode.comfort).opacity, 1.0);
      expect(
        _scaleX(_scaleOf(tester, DriveMode.comfort)),
        1.0,
      );

      // Sport pulses: mid-cycle (800 ms of 1600) → intensity ≈ 1 → peak opacity/scale.
      await _emitMode(tester, signals, DriveMode.sport);
      // controller starts at 0 → intensity 0 → floor opacity/scale.
      final sportOp0 = _opacityOf(tester, DriveMode.sport).opacity;
      expect(
        sportOp0,
        closeTo(DriveModeCornerDotLayer.kSportPulseOpacityMin, 0.02),
      );
      final sportSc0 =
          _scaleX(_scaleOf(tester, DriveMode.sport));
      expect(
        sportSc0,
        closeTo(DriveModeCornerDotLayer.kSportPulseScaleMin, 0.02),
      );

      await tester.pump(const Duration(milliseconds: 800));
      final sportOpMid = _opacityOf(tester, DriveMode.sport).opacity;
      final sportScMid =
          _scaleX(_scaleOf(tester, DriveMode.sport));
      expect(sportOpMid, closeTo(1.0, 0.05));
      expect(
        sportScMid,
        closeTo(DriveModeCornerDotLayer.kSportPulseScaleMax, 0.05),
      );
      expect(sportOpMid, greaterThan(sportOp0));
      expect(sportScMid, greaterThan(sportSc0));

      // Still red through the pulse.
      final sportDeco =
          tester.widget<DecoratedBox>(_dot(DriveMode.sport)).decoration as BoxDecoration;
      expect(sportDeco.color, const Color(0xFFFF3B30));
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

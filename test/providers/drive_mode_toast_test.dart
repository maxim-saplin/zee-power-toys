import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/providers/drive_mode_toast.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  group('DriveModeToastNotifier', () {
    test('cold bootstrap does not toast; change does', () {
      final signals = FakeCarSignals();
      final container = ProviderContainer(
        overrides: [
          carSignalsProvider.overrideWithValue(signals),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(driveModeToastProvider.notifier);
      n.debugSetSeen(DriveMode.comfort);
      expect(container.read(driveModeToastProvider), isNull);
      n.onEvent(DriveMode.comfort);
      expect(container.read(driveModeToastProvider), isNull);
      n.onEvent(DriveMode.sport);
      expect(container.read(driveModeToastProvider)?.mode, DriveMode.sport);
      n.debugClear();
    });

    test('FAIL fix: bootstrap(unknown) then first seed → no toast; then change → toast',
        () {
      final signals = FakeCarSignals();
      final container = ProviderContainer(
        overrides: [
          carSignalsProvider.overrideWithValue(signals),
        ],
      );
      addTearDown(container.dispose);
      // Mimic HUD cold-open: snapshot unknown, then seed DriveModeEvent(comfort).
      final n = container.read(driveModeToastProvider.notifier);
      expect(container.read(driveModeToastProvider), isNull);
      n.onEvent(DriveMode.comfort); // first known after unknown — baseline only
      expect(container.read(driveModeToastProvider), isNull,
          reason: 'cold-open / HUD seed must never toast');
      n.onEvent(DriveMode.eco); // real change
      expect(container.read(driveModeToastProvider)?.mode, DriveMode.eco);
      n.onEvent(DriveMode.sport);
      expect(container.read(driveModeToastProvider)?.mode, DriveMode.sport);
      n.debugClear();
    });

    test('unknown soft-skipped; other shows Mode toast after known baseline', () {
      final signals = FakeCarSignals();
      final container = ProviderContainer(
        overrides: [
          carSignalsProvider.overrideWithValue(signals),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(driveModeToastProvider.notifier);
      n.debugSetSeen(DriveMode.eco);
      n.onEvent(DriveMode.unknown);
      expect(container.read(driveModeToastProvider), isNull);
      n.onEvent(DriveMode.other);
      expect(container.read(driveModeToastProvider)?.mode, DriveMode.other);
      n.debugClear();
    });
  });

  group('HUD toast on Simulated change', () {
    testWidgets('cold-open seed Comfort → no toast; then Sport → toast',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 800, height: 480, child: HudRoot()),
        signals: signals,
        localizations: false,
      ));
      await tester.pump();

      // HUD Fake starts unknown; seed first known (mirrors seedHudFromCarSignals).
      signals.emitDriveMode(DriveMode.comfort);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('drive-mode-toast')), findsNothing,
          reason: 'cold-open seed must not toast');

      signals.emitDriveMode(DriveMode.sport);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('drive-mode-toast')), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);
    });

    testWidgets('ECO→Sport after known baseline shows Sport toast', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 800, height: 480, child: HudRoot()),
        signals: signals,
        localizations: false,
      ));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HudRoot)),
      );
      container
          .read(driveModeToastProvider.notifier)
          .debugSetSeen(DriveMode.eco);
      await tester.pump();
      expect(find.byKey(const ValueKey('drive-mode-toast')), findsNothing);

      signals.emitDriveMode(DriveMode.sport);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('drive-mode-toast')), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);
    });
  });
}

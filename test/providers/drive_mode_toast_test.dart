import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/providers/drive_mode_toast.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/providers/services.dart';

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

    test('unknown soft-skipped; other shows Mode toast', () {
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
    testWidgets('Comfort→Sport shows Sport toast', (tester) async {
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
          .debugSetSeen(DriveMode.comfort);
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

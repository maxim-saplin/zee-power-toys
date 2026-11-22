import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/media_now_playing.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  testWidgets('bottom cluster keeps battery rows inside an overflowing slot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(220, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final signals = FakeCarSignals();
    final media = FakeMediaNowPlaying();
    const config = AppConfig(
      battery: BatteryConfig(
        placement: BatteryPlacement.rightBottom,
        sizeScale: 2.5,
      ),
      media: MediaConfig(showMedia: true),
    );

    await tester.pumpWidget(
      wrapWithProviders(
        const SizedBox(width: 220, height: 100, child: BatteryWidget()),
        config: config,
        signals: signals,
        media: media,
        scaffold: true,
        localizations: false,
      ),
    );
    signals.emitBattery(levelPct: 72, tempC: 31);
    signals.emitCharge(charging: true, kw: 11);
    media.setNowPlaying(
      const MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.4),
    );
    await tester.pump();

    final slot = tester.getRect(find.byType(BatteryWidget));
    final pct = tester.getRect(find.byKey(const ValueKey('battery-pct-text')));
    final temp = tester.getRect(
      find.byKey(const ValueKey('battery-temp-text')),
    );
    final baseRows = pct.expandToInclude(temp);
    final stats = tester.getRect(find.byKey(const ValueKey('charging-stats')));
    final mediaRow = tester.getRect(
      find.byKey(const ValueKey('hud-media-chrome')),
    );

    expect(
      baseRows.bottom,
      lessThanOrEqualTo(slot.bottom),
      reason: 'existing battery rows must retain the bottom anchor',
    );
    expect(
      stats.bottom,
      lessThan(baseRows.top),
      reason: 'charging row must be inserted above base rows',
    );
    expect(
      mediaRow.bottom,
      lessThan(stats.top),
      reason: 'media row must be inserted above charging rows',
    );
  });

  testWidgets(
    'bottom cluster base stays fixed as charging and media are added',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(220, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final signals = FakeCarSignals();
      final media = FakeMediaNowPlaying();
      const config = AppConfig(
        battery: BatteryConfig(
          placement: BatteryPlacement.rightBottom,
          sizeScale: 2.5,
        ),
        media: MediaConfig(showMedia: true),
      );

      await tester.pumpWidget(
        wrapWithProviders(
          const SizedBox(width: 220, height: 100, child: BatteryWidget()),
          config: config,
          signals: signals,
          media: media,
          scaffold: true,
          localizations: false,
        ),
      );

      signals.emitBattery(levelPct: 72, tempC: 31);
      await tester.pump();

      Rect baseRows() {
        final pct = tester.getRect(
          find.byKey(const ValueKey('battery-pct-text')),
        );
        final temp = tester.getRect(
          find.byKey(const ValueKey('battery-temp-text')),
        );
        return pct.expandToInclude(temp);
      }

      final slot = tester.getRect(find.byType(BatteryWidget));
      final idleBase = baseRows();

      signals.emitCharge(charging: true, kw: 11);
      await tester.pump();
      final chargingBase = baseRows();

      media.setNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.4),
      );
      await tester.pump();
      final chargingMediaBase = baseRows();

      expect(
        chargingBase.bottom,
        closeTo(idleBase.bottom, 0.01),
        reason: 'charging must not move the base bottom edge',
      );
      expect(
        chargingMediaBase.bottom,
        closeTo(idleBase.bottom, 0.01),
        reason: 'media must not move the base bottom edge',
      );
      expect(
        slot.bottom - chargingMediaBase.bottom,
        lessThan(20),
        reason: 'the normal bottom cluster must not leave a large idle gap',
      );

      final stats = tester.getRect(
        find.byKey(const ValueKey('charging-stats')),
      );
      final mediaRow = tester.getRect(
        find.byKey(const ValueKey('hud-media-chrome')),
      );
      expect(mediaRow.bottom, lessThan(stats.top));
      expect(stats.bottom, lessThan(chargingMediaBase.top));
    },
  );
}

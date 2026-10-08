// The battery % / temp rows must not move when media chrome appears or
// disappears, for every placement and for a manually bottom-pushed slider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/media_now_playing.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  void expectSameRect(Rect actual, Rect expected, String reason) {
    expect(actual.left, closeTo(expected.left, 0.01), reason: reason);
    expect(actual.top, closeTo(expected.top, 0.01), reason: reason);
    expect(actual.right, closeTo(expected.right, 0.01), reason: reason);
    expect(actual.bottom, closeTo(expected.bottom, 0.01), reason: reason);
  }

  const surface = Size(1024, 576);
  const track = MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.4);

  for (final placement in BatteryPlacement.values) {
    for (final vert in <double?>[null, 0.7]) {
      testWidgets('rows stay put on media toggle: ${placement.name} '
          'vertFrac=${vert ?? 'preset'}', (tester) async {
        await tester.binding.setSurfaceSize(surface);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final signals = FakeCarSignals();
        final media = FakeMediaNowPlaying();
        var battery = BatteryConfig().withPlacement(placement);
        if (vert != null) battery = battery.copyWith(vertFrac: vert);
        await tester.pumpWidget(
          wrapWithProviders(
            const HudRoot(),
            signals: signals,
            media: media,
            config: AppConfig(battery: battery),
          ),
        );
        signals.emitBattery(levelPct: 72, tempC: 31.0);
        await tester.pump();

        Rect rowsRect() => tester
            .getRect(find.byKey(const ValueKey('battery-pct-text')))
            .expandToInclude(
              tester.getRect(find.byKey(const ValueKey('battery-temp-text'))),
            );

        final idle = rowsRect();
        expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);

        media.setNowPlaying(track);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('hud-media-chrome')), findsOneWidget);
        expectSameRect(rowsRect(), idle, 'rows moved when media appeared');

        media.setNowPlaying(null);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);
        expectSameRect(rowsRect(), idle, 'rows moved when media vanished');
      });
    }
  }
}

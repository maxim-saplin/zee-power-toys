import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/media_now_playing.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  group('MediaConfig model', () {
    test('defaults are B · compact (all pieces on, barOnly off)', () {
      const cfg = MediaConfig();
      expect(cfg.showMedia, isTrue);
      expect(cfg.showIcon, isTrue);
      expect(cfg.showArtistSong, isTrue);
      expect(cfg.showProgressBar, isTrue);
      expect(cfg.barOnly, isFalse);
    });

    test('round-trips through JSON', () {
      const cfg = MediaConfig(
        showMedia: true,
        showIcon: false,
        showArtistSong: true,
        showProgressBar: true,
        barOnly: true,
      );
      expect(MediaConfig.fromJson(cfg.toJson()), equals(cfg));
    });

    test('AppConfig carries media defaults', () {
      const app = AppConfig();
      expect(app.media, equals(const MediaConfig()));
      final round = AppConfig.fromJson(app.toJson());
      expect(round.media, equals(const MediaConfig()));
    });
  });

  group('BatteryWidget media chrome B · compact', () {
    Future<void> pumpBattery(
      WidgetTester tester, {
      required MediaNowPlayingSource media,
      MediaConfig mediaCfg = const MediaConfig(),
      BatteryConfig batteryCfg = const BatteryConfig(),
    }) async {
      final signals = FakeCarSignals();
      signals.emitBattery(levelPct: 72, tempC: 31);
      await pumpHud(
        tester,
        wrapWithProviders(
          const BatteryWidget(),
          signals: signals,
          media: media,
          config: AppConfig(battery: batteryCfg, media: mediaCfg),
          scaffold: true,
        ),
      );
      await tester.pump();
    }

    testWidgets('compact: icon + artist — song + bar, no times', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Song',
          progress: 0.42,
        ),
      );
      await pumpBattery(tester, media: media);

      expect(find.byKey(const ValueKey('hud-media-chrome')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsOneWidget);
      expect(find.text('Artist — Song'), findsOneWidget);
      // 0124: artist — song larger than 0123 B·compact (base*0.42 → base*0.55).
      final mediaText =
          tester.widget<Text>(find.byKey(const ValueKey('hud-media-artist-song')));
      expect(mediaText.style?.fontSize, closeTo(20.0 * 0.55, 0.01));
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
      // No time labels (no mm:ss).
      expect(find.textContaining(':'), findsNothing);
      // Battery cluster still below (0124 default = justText % + temp).
      expect(find.byKey(const ValueKey('battery-icon')), findsNothing);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-temp-text')), findsOneWidget);
    });

    testWidgets('bar-only minimal: progress only', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Song',
          progress: 0.5,
        ),
      );
      await pumpBattery(
        tester,
        media: media,
        mediaCfg: const MediaConfig(barOnly: true),
      );
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-icon')), findsNothing);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsNothing);
    });

    testWidgets('hidden when showMedia=false', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Song',
          progress: 0.2,
        ),
      );
      await pumpBattery(
        tester,
        media: media,
        mediaCfg: const MediaConfig(showMedia: false),
      );
      expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);
    });

    testWidgets('hidden when not playing', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Song',
          progress: 0.2,
          isPlaying: false,
        ),
      );
      await pumpBattery(tester, media: media);
      expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);
    });

    testWidgets('per-piece: icon off keeps text+bar', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'A',
          title: 'B',
          progress: 0.1,
        ),
      );
      await pumpBattery(
        tester,
        media: media,
        mediaCfg: const MediaConfig(showIcon: false),
      );
      expect(find.byKey(const ValueKey('hud-media-icon')), findsNothing);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
    });
  });
}

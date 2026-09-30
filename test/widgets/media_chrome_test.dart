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
    test('stores one toggle and reads legacy display settings', () {
      final config = MediaConfig.fromJson(<String, Object?>{
        'showMedia': false,
        'showIcon': true,
        'showArtistSong': false,
        'showProgressBar': false,
        'barOnly': true,
      });

      expect(config.showMedia, isFalse);
      expect(config.toJson(), <String, Object?>{'showMedia': false});
      expect(MediaConfig.fromJson(const {}).showMedia, isTrue);
    });

    test('defaults enabled and round-trips', () {
      const cfg = MediaConfig();
      expect(cfg.showMedia, isTrue);
      expect(MediaConfig.fromJson(cfg.toJson()), equals(cfg));
    });

    test('AppConfig carries media defaults', () {
      const app = AppConfig();
      expect(app.media, equals(const MediaConfig()));
      final round = AppConfig.fromJson(app.toJson());
      expect(round.media, equals(const MediaConfig()));
    });
  });

  group('BatteryWidget media progress and track notice', () {
    Future<void> pumpBattery(
      WidgetTester tester, {
      required MediaNowPlayingSource media,
      MediaConfig mediaCfg = const MediaConfig(),
      BatteryConfig batteryCfg = const BatteryConfig(),
      bool emitBattery = true,
    }) async {
      final signals = FakeCarSignals();
      if (emitBattery) signals.emitBattery(levelPct: 72, tempC: 31);
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

    testWidgets('first newly playing track shows its transient label', (
      tester,
    ) async {
      final media = FakeMediaNowPlaying();
      await pumpBattery(tester, media: media, emitBattery: false);

      expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);

      media.setNowPlaying(
        const MediaNowPlaying(
          artist: 'New Artist',
          title: 'First Track',
          progress: 0.2,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('New Artist — First Track'), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
    });

    testWidgets('default presentation shows progress only', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.42),
      );
      await pumpBattery(tester, media: media);

      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-icon')), findsNothing);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsNothing);
    });

    testWidgets('a track changed while paused is labeled on playback', (
      tester,
    ) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Playing',
          progress: 0.1,
        ),
      );
      await pumpBattery(tester, media: media);

      media.setNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Changed While Paused',
          progress: 0.1,
          isPlaying: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('hud-media-chrome')), findsNothing);

      media.setNowPlaying(
        const MediaNowPlaying(
          artist: 'Artist',
          title: 'Changed While Paused',
          progress: 0.1,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Artist — Changed While Paused'), findsOneWidget);
    });

    testWidgets('track change shows a five-second text-only label', (
      tester,
    ) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(
          artist: 'First Artist',
          title: 'First Song',
          progress: 0.1,
        ),
      );
      await pumpBattery(tester, media: media);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsNothing);
      final temperatureFinder = find.byKey(const ValueKey('battery-temp-text'));
      final temperatureOffsetBefore = tester.getTopLeft(temperatureFinder);

      media.setNowPlaying(
        const MediaNowPlaying(
          artist: 'Next Artist',
          title: 'Next Song',
          progress: 0.2,
        ),
      );
      await tester.pump();
      await tester.pump();

      final labelFinder = find.byKey(const ValueKey('hud-media-artist-song'));
      expect(find.text('Next Artist — Next Song'), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-icon')), findsNothing);
      final label = tester.widget<Text>(labelFinder);
      final temperature = tester.widget<Text>(temperatureFinder);
      expect(label.style?.fontSize, temperature.style?.fontSize);
      expect(tester.getTopLeft(temperatureFinder), temperatureOffsetBefore);

      await tester.pump(const Duration(seconds: 4));
      media.setNowPlaying(
        const MediaNowPlaying(
          artist: 'Next Artist',
          title: 'Next Song',
          progress: 0.7,
        ),
      );
      await tester.pump();
      expect(labelFinder, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(labelFinder, findsNothing);
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
    });

    testWidgets('a later track change starts a fresh five-second window', (
      tester,
    ) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'First', progress: 0.1),
      );
      await pumpBattery(tester, media: media);

      media.setNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Second', progress: 0.2),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      media.setNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Third', progress: 0.3),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Artist — Third'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Artist — Third'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsNothing);
    });

    testWidgets('progress bar stays with battery percentage and temperature', (
      tester,
    ) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.42),
      );
      await pumpBattery(tester, media: media);

      expect(find.byKey(const ValueKey('hud-media-chrome')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-media-icon')), findsNothing);
      expect(find.byKey(const ValueKey('hud-media-artist-song')), findsNothing);
      expect(find.byKey(const ValueKey('battery-icon')), findsNothing);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-temp-text')), findsOneWidget);
    });

    testWidgets('hidden when showMedia=false', (tester) async {
      final media = FakeMediaNowPlaying(
        const MediaNowPlaying(artist: 'Artist', title: 'Song', progress: 0.2),
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
  });
}

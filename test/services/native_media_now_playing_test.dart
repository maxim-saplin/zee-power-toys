import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/adapters/native_media_now_playing.dart';
import 'package:zee_power_toys/services/media_now_playing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('zee/media'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zee/media'), null);
  });

  group('NativeMediaNowPlaying.onNativeEvent', () {
    late NativeMediaNowPlaying sut;
    late List<MediaNowPlaying?> received;

    setUp(() {
      sut = NativeMediaNowPlaying();
      received = [];
      sut.changes.listen(received.add);
    });

    tearDown(() => sut.dispose());

    test('active session → artist/title/progress', () async {
      sut.onNativeEvent({
        'active': true,
        'artist': 'Artist',
        'title': 'Song',
        'progress': 0.42,
        'isPlaying': true,
        'source': 'mediasession',
      });
      await Future<void>.value();
      expect(sut.current?.artist, 'Artist');
      expect(sut.current?.title, 'Song');
      expect(sut.current?.progress, closeTo(0.42, 1e-9));
      expect(sut.current?.isPlaying, isTrue);
      expect(sut.debugSourceKind, 'mediasession');
      expect(received, isNotEmpty);
    });

    test('inactive clears current', () async {
      sut.onNativeEvent({
        'active': true,
        'artist': 'A',
        'title': 'T',
        'progress': 0.1,
        'isPlaying': true,
      });
      await Future<void>.value();
      sut.onNativeEvent({'active': false, 'source': 'mediasession'});
      await Future<void>.value();
      expect(sut.current, isNull);
    });

    test('empty artist+title treated as inactive', () async {
      sut.onNativeEvent({
        'active': true,
        'artist': '',
        'title': '  ',
        'progress': 0.5,
        'isPlaying': true,
      });
      await Future<void>.value();
      expect(sut.current, isNull);
    });

    test('inject setNowPlaying overrides until next native', () async {
      sut.setNowPlaying(
        const MediaNowPlaying(artist: 'Inj', title: 'ect', progress: 0.2),
      );
      expect(sut.debugSourceKind, 'inject');
      expect(sut.current?.artist, 'Inj');
      sut.onNativeEvent({
        'active': true,
        'artist': 'Native',
        'title': 'Track',
        'progress': 0.9,
        'isPlaying': true,
        'source': 'mediasession',
      });
      await Future<void>.value();
      expect(sut.current?.artist, 'Native');
      expect(sut.debugSourceKind, 'mediasession');
    });
  });

  group('MediaNowPlaying.fromJson', () {
    test('round-trips', () {
      const np = MediaNowPlaying(
        artist: 'A',
        title: 'B',
        progress: 0.5,
        isPlaying: false,
      );
      expect(MediaNowPlaying.fromJson(np.toJson()), equals(np));
    });

    test('clear envelope → null', () {
      expect(
        MediaNowPlaying.fromJson(<String, Object?>{'clear': true}),
        isNull,
      );
    });
  });
}

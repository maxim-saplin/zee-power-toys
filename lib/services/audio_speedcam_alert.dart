import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'speedcam_alert.dart';
import 'speedcam_alien_ping.dart';

/// Asset sting — `assets/sounds/speedcam_sting.wav`.
///
/// Uses sonification audio context with **no exclusive focus** so YNavi /
/// music keep playing (Maxim bar: must not pause media).
class AudioSpeedcamAlert implements SpeedcamAlert {
  AudioSpeedcamAlert({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    // Fire-and-forget; play paths also ensure context before playback.
    _ensureSonificationContext();
  }

  final AudioPlayer _player;
  static const asset = 'sounds/speedcam_sting.wav';
  static const pingAsset = 'sounds/speedcam_alien_ping.wav';

  /// Short HUD cues must not take AUDIOFOCUS_GAIN (default pauses others).
  static final AudioContext _sonificationContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );

  Future<void> _ensureSonificationContext() async {
    try {
      await _player.setAudioContext(_sonificationContext);
    } catch (e) {
      debugPrint('speedcam audio context failed: $e');
    }
  }

  @override
  Future<void> playSting() async {
    try {
      await _ensureSonificationContext();
      await _player.stop();
      await _player.setPlaybackRate(1.0);
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('speedcam sting failed: $e');
    }
  }

  @override
  Future<void> playAlienPing({double? distanceM}) async {
    try {
      await _ensureSonificationContext();
      final rate = distanceM == null
          ? 1.0
          : alienPingPlaybackRateForDistanceM(distanceM);
      await _player.stop();
      await _player.setPlaybackRate(rate);
      await _player.play(AssetSource(pingAsset));
    } catch (e) {
      debugPrint('speedcam alien ping failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

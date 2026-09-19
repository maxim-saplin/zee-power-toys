import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'speedcam_alert.dart';
import 'speedcam_alien_ping.dart';

/// Asset sting — `assets/sounds/speedcam_sting.wav`.
class AudioSpeedcamAlert implements SpeedcamAlert {
  AudioSpeedcamAlert({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  static const asset = 'sounds/speedcam_sting.wav';
  static const pingAsset = 'sounds/speedcam_alien_ping.wav';

  @override
  Future<void> playSting() async {
    try {
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

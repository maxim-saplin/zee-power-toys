import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'speedcam_alert.dart';

/// Asset sting — `assets/sounds/speedcam_sting.wav`.
class AudioSpeedcamAlert implements SpeedcamAlert {
  AudioSpeedcamAlert({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  static const asset = 'sounds/speedcam_sting.wav';

  @override
  Future<void> playSting() async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('speedcam sting failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'speedcam_alert.dart';
import 'speedcam_alien_ping.dart';

/// Maps in-app slider 0…1 → MediaPlayer gain.
///
/// - 0 → mute (no play)
/// - curve lifts mid-slider so changes are audible
/// - 1 → full digital gain (1.0); loudness then limited by the car **Navigation**
///   volume group (see [AudioSpeedcamAlert] docs)
double speedcamAlertPlayerGain(double slider) {
  final s = slider.clamp(0.0, 1.0);
  if (s <= 0) return 0;
  // Perceptual: quieter at low end, full at max (not a soft cap).
  return math.pow(s, 0.65).toDouble().clamp(0.0, 1.0);
}

/// Asset sting / Alien ping — `assets/sounds/speedcam_*.wav`.
///
/// **Car volume owner (0059):** Android `USAGE_ASSISTANCE_NAVIGATION_GUIDANCE`
/// → AAOS / Zeekr **Navigation** volume group (not Media, not Ringtone, not
/// System/sonification FX). Raise the car's NAV knob + in-app Alert volume.
///
/// **Focus:** [AndroidAudioFocus.none] — must not pause YNavi / media
/// (Maxim bar). Content stays sonification; usage is navigation so the alert
/// is on a crankable stream.
///
/// Prior `USAGE_ASSISTANCE_SONIFICATION` mapped to a quiet system/FX path that
/// ignored Media/NAV/Ringtone knobs and made the in-app slider feel dead.
class AudioSpeedcamAlert implements SpeedcamAlert {
  AudioSpeedcamAlert({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _ensureAlertContext();
  }

  final AudioPlayer _player;
  double _slider = 0.85;

  static const asset = 'sounds/speedcam_sting.wav';
  static const pingAsset = 'sounds/speedcam_alien_ping.wav';

  /// Navigation usage + no exclusive focus (mixes with media/YNavi).
  static final AudioContext _alertContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceNavigationGuidance,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      // ambient already mixes; explicit mixWithOthers is disallowed for ambient.
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );

  double get _gain => speedcamAlertPlayerGain(_slider);

  Future<void> _ensureAlertContext() async {
    try {
      await _player.setAudioContext(_alertContext);
      await _player.setReleaseMode(ReleaseMode.stop);
      // Context apply can reset platform gain — re-apply slider.
      await _player.setVolume(_gain);
    } catch (e) {
      debugPrint('speedcam audio context failed: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _slider = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_gain);
    } catch (e) {
      debugPrint('speedcam volume failed: $e');
    }
  }

  @override
  Future<void> playSting() async {
    final g = _gain;
    if (g <= 0) return;
    try {
      await _ensureAlertContext();
      await _player.stop();
      await _player.setPlaybackRate(1.0);
      // Pass volume into play — setVolume-before-play alone was ignored on
      // some car MediaPlayer paths after setAudioContext.
      await _player.play(AssetSource(asset), volume: g);
    } catch (e) {
      debugPrint('speedcam sting failed: $e');
    }
  }

  @override
  Future<void> playAlienPing({double? distanceM}) async {
    final g = _gain;
    if (g <= 0) return;
    try {
      await _ensureAlertContext();
      final rate = distanceM == null
          ? 1.0
          : alienPingPlaybackRateForDistanceM(distanceM);
      await _player.stop();
      await _player.setPlaybackRate(rate);
      await _player.play(AssetSource(pingAsset), volume: g);
    } catch (e) {
      debugPrint('speedcam alien ping failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

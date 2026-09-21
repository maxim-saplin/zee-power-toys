import '../speedcam_alert.dart';

class FakeSpeedcamAlert implements SpeedcamAlert {
  int playCount = 0;
  int pingCount = 0;
  double? lastPingDistanceM;
  double volume = 1.0;

  @override
  Future<void> playSting() async {
    if (volume <= 0) return;
    playCount++;
  }

  @override
  Future<void> playAlienPing({double? distanceM}) async {
    if (volume <= 0) return;
    pingCount++;
    lastPingDistanceM = distanceM;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> dispose() async {}
}

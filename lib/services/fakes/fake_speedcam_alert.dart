import '../speedcam_alert.dart';

class FakeSpeedcamAlert implements SpeedcamAlert {
  int playCount = 0;
  int pingCount = 0;
  double? lastPingDistanceM;

  @override
  Future<void> playSting() async {
    playCount++;
  }

  @override
  Future<void> playAlienPing({double? distanceM}) async {
    pingCount++;
    lastPingDistanceM = distanceM;
  }

  @override
  Future<void> dispose() async {}
}

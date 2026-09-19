import '../speedcam_alert.dart';

class FakeSpeedcamAlert implements SpeedcamAlert {
  int playCount = 0;
  int pingCount = 0;

  @override
  Future<void> playSting() async {
    playCount++;
  }

  @override
  Future<void> playAlienPing() async {
    pingCount++;
  }

  @override
  Future<void> dispose() async {}
}

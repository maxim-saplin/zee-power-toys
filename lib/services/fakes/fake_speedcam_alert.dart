import '../speedcam_alert.dart';

class FakeSpeedcamAlert implements SpeedcamAlert {
  int playCount = 0;

  @override
  Future<void> playSting() async {
    playCount++;
  }

  @override
  Future<void> dispose() async {}
}

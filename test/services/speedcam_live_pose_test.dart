import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('manual pose holds off live until clearHostPose', () async {
    final svc = FakeSpeedcamService();
    await svc.setHostPose(const SpeedcamHostPose(lat: 1, lon: 2, speedKmh: 10));
    expect(svc.snapshot.host!.lat, 1);

    await svc.setHostPose(
      const SpeedcamHostPose(lat: 9, lon: 9, speedKmh: 99),
      fromLive: true,
    );
    expect(svc.snapshot.host!.lat, 1, reason: 'live must not stomp manual');

    await svc.clearHostPose();
    await svc.setHostPose(
      const SpeedcamHostPose(lat: 53.9, lon: 27.5, speedKmh: 40),
      fromLive: true,
    );
    expect(svc.snapshot.host!.lat, 53.9);
    expect(svc.snapshot.host!.lon, 27.5);
  });

  test('clearHostPose fires onHostPoseCleared for live re-seed (0050 HARD)', () async {
    final svc = FakeSpeedcamService();
    var cleared = 0;
    SpeedcamHostPose? reseed;
    svc.onHostPoseCleared = () {
      cleared++;
      // Simulate NativeSpeedcamLocation.resumeLiveAfterClear cache re-apply.
      reseed = const SpeedcamHostPose(lat: 52.46, lon: 30.81, speedKmh: 40);
      // ignore: discarded_futures
      svc.setHostPose(reseed!, fromLive: true);
    };

    await svc.setHostPose(const SpeedcamHostPose(lat: 1, lon: 2));
    expect(svc.snapshot.host!.lat, 1);

    await svc.clearHostPose();
    expect(cleared, 1);
    expect(svc.snapshot.host!.lat, 52.46, reason: 'live must resume after clear');
    expect(svc.snapshot.host!.lon, 30.81);
  });
}

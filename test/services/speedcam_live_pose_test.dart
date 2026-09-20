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
}

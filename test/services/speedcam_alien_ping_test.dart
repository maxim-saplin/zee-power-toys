import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/speedcam_alien_ping.dart';

void main() {
  test('Alien ping interval tightens as distance closes', () {
    final far = alienPingIntervalForDistanceM(500);
    final mid = alienPingIntervalForDistanceM(200);
    final near = alienPingIntervalForDistanceM(40);
    expect(far.inMilliseconds, greaterThan(mid.inMilliseconds));
    expect(mid.inMilliseconds, greaterThan(near.inMilliseconds));
    expect(near.inMilliseconds, greaterThanOrEqualTo(100));
    expect(far.inMilliseconds, lessThanOrEqualTo(1500));
  });
}

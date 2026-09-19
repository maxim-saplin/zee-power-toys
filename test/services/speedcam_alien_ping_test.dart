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

  test('Alien ping playback rate rises as distance closes (whistle)', () {
    final far = alienPingPlaybackRateForDistanceM(500);
    final mid = alienPingPlaybackRateForDistanceM(200);
    final near = alienPingPlaybackRateForDistanceM(40);
    expect(near, greaterThan(mid));
    expect(mid, greaterThan(far));
    expect(far, greaterThanOrEqualTo(0.85));
    expect(near, lessThanOrEqualTo(1.9));
  });
}

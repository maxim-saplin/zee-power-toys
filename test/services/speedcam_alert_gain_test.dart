import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/audio_speedcam_alert.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_alert.dart';

void main() {
  group('speedcamAlertPlayerGain', () {
    test('0 → mute; 1 → full; mid audible', () {
      expect(speedcamAlertPlayerGain(0), 0);
      expect(speedcamAlertPlayerGain(1), closeTo(1.0, 1e-9));
      final mid = speedcamAlertPlayerGain(0.5);
      expect(mid, greaterThan(0.5)); // curve lifts mid vs linear
      expect(mid, lessThan(1.0));
    });
  });

  test('FakeSpeedcamAlert mute skips play; volume tracks slider', () async {
    final alert = FakeSpeedcamAlert();
    await alert.setVolume(0);
    await alert.playSting();
    expect(alert.playCount, 0);
    await alert.setVolume(0.85);
    await alert.playSting();
    expect(alert.playCount, 1);
    expect(alert.volume, closeTo(0.85, 1e-9));
  });
}

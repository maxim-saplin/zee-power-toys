import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_alert.dart';
import 'package:zee_power_toys/services/speedcam_alert.dart';

void main() {
  group('SpeedcamApproachArm', () {
    late FakeSpeedcamAlert alert;
    late SpeedcamApproachArm arm;

    setUp(() {
      alert = FakeSpeedcamAlert();
      arm = SpeedcamApproachArm(alert: alert);
    });

    test('200 m enter plays once; stay silent; 800 m re-arms; re-enter plays', () async {
      expect(await arm.onInsideApproach(false), isFalse);
      expect(await arm.onInsideApproach(true), isTrue); // 200 enter
      expect(alert.playCount, 1);
      expect(await arm.onInsideApproach(true), isFalse); // still inside
      expect(alert.playCount, 1);
      expect(await arm.onInsideApproach(false), isFalse); // 800 exit
      expect(await arm.onInsideApproach(true), isTrue); // re-enter
      expect(alert.playCount, 2);
    });

    test('disabled never plays; re-arms on exit', () async {
      arm.enabled = false;
      expect(await arm.onInsideApproach(true), isFalse);
      expect(alert.playCount, 0);
      arm.enabled = true;
      // still inside from before — need exit to re-arm cleanly
      await arm.onInsideApproach(false);
      expect(await arm.onInsideApproach(true), isTrue);
      expect(alert.playCount, 1);
    });
  });
}

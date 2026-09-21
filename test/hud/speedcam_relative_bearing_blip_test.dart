import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('relativeBearingDegrees folds absolute cam bearing by host heading', () {
    // Host driving east (90°); cam due east of host → absolute ~90° → relative 0 (ahead).
    expect(relativeBearingDegrees(90, 90), closeTo(0, 1e-9));
    // Cam north of host while driving east → absolute 0 → relative -90 (left).
    expect(relativeBearingDegrees(0, 90), closeTo(-90, 1e-9));
    // Unknown heading: absolute treated as relative.
    expect(relativeBearingDegrees(45, null), closeTo(45, 1e-9));
  });

  test('on-route ahead stays inside Alien ±50° wedge after fold', () {
    const heading = 200.0; // SSW
    const absAhead = 205.0; // slightly right of travel
    final rel = relativeBearingDegrees(absAhead, heading);
    expect(rel.abs(), lessThan(50),
        reason: 'ahead cam must not be gated out of Alien fan');
  });
}

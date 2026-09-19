import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';

void main() {
  test('Alien blip radius/alpha increase as range closes', () {
    const display = 500.0;
    final farR = alienBlipRadiusForDistanceM(400, displayRadiusM: display);
    final nearR = alienBlipRadiusForDistanceM(80, displayRadiusM: display);
    expect(nearR, greaterThan(farR));

    final farA = alienBlipAlphaForDistanceM(400, displayRadiusM: display);
    final nearA = alienBlipAlphaForDistanceM(80, displayRadiusM: display);
    expect(nearA, greaterThan(farA));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';

void main() {
  test('HUD / narrow surface: bridge identity — gold CRT unchanged', () {
    expect(
      alienDhuDpiBridge(devicePixelRatio: 1.0, surfaceLogicalWidth: 1024),
      1.0,
    );
    expect(
      alienDhuDpiBridge(devicePixelRatio: 2.0, surfaceLogicalWidth: 2560),
      1.0,
    );
  });

  test('DHU automotive (wide + low reported dpr): bridge ≈ 200.6/160', () {
    final b = alienDhuDpiBridge(
      devicePixelRatio: 1.0,
      surfaceLogicalWidth: 2560,
    );
    expect(b, closeTo(200.6 / 160.0, 0.01));
  });
}

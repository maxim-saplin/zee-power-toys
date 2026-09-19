import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/speedcam_settings_screen.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

import '../support/harness.dart';

void main() {
  test('approach inject + clear matches Demo/Stop semantics', () async {
    final speedcam = FakeSpeedcamService();
    final cam = speedcam.snapshot.cams.firstWhere(
      (c) => c.direction == null || c.direction!.trim().isEmpty,
      orElse: () => speedcam.snapshot.cams.first,
    );
    final dLat = 200 / 111320.0;
    await speedcam.setHostPose(SpeedcamHostPose(
      lat: cam.lat - dLat,
      lon: cam.lon,
      speedKmh: 50,
    ));
    expect(speedcam.snapshot.danger?.insideApproach, isTrue);

    await speedcam.clearHostPose();
    expect(speedcam.snapshot.host, isNull);
    expect(speedcam.snapshot.danger, isNull);
  });

  testWidgets('Speedcam settings shows Demo on HUD + Stop', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsConfigStore();
    await store.load();

    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithProviders(const SpeedcamSettingsScreen(), store: store),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('speedcam-hud-demo')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-hud-demo-stop')), findsOneWidget);
  });
}

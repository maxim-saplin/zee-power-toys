import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  testWidgets('hidden when no danger', (tester) async {
    final svc = FakeSpeedcamService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SpeedcamRadarWidget()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('hud-speedcam-radar')), findsNothing);
    svc.dispose();
  });

  testWidgets('visible on forceDemoDanger', (tester) async {
    final svc = FakeSpeedcamService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 160,
              child: SpeedcamRadarWidget(
                forceDemoDanger: SpeedcamRadarWidget.demoDanger,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('hud-speedcam-radar')), findsOneWidget);
    svc.dispose();
  });

  testWidgets('visible when live approach inside 500m', (tester) async {
    final svc = FakeSpeedcamService();
    final cam = svc.snapshot.cams.first;
    await svc.approachCam(cam, distanceM: 200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 160,
              child: SpeedcamRadarWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('hud-speedcam-radar')), findsOneWidget);
    svc.dispose();
  });
}

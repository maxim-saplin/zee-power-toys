import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hidden when no danger', (tester) async {
    final svc = FakeSpeedcamService();
    final store = SharedPrefsConfigStore();
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
          configStoreProvider.overrideWithValue(store),
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
    final store = SharedPrefsConfigStore();
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
          configStoreProvider.overrideWithValue(store),
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

  testWidgets('DHU large alwaysShow paints dhu key', (tester) async {
    final svc = FakeSpeedcamService();
    final store = SharedPrefsConfigStore();
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(svc),
          configStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              height: 280,
              child: SpeedcamRadarWidget(
                variant: SpeedcamRadarVariant.dhuLarge,
                alwaysShow: true,
                displayRadiusM: 2000,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dhu-speedcam-radar')), findsOneWidget);
    svc.dispose();
  });
}

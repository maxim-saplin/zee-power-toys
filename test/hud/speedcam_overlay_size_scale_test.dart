import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/hud/speedcam_crt_geometry.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_alert.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('0106: Alien CRT fills overlay slot — content scales with window',
      (tester) async {
    final svc = FakeSpeedcamService();
    final store = SharedPrefsConfigStore();
    await store.load();
    await store.setConfig(
      store.value.copyWith(
        speedcam: store.value.speedcam.copyWith(
          radarLook: SpeedcamRadarLook.alien,
          dhuSystemOverlay: true,
        ),
      ),
    );

    Future<Size> pumpSlot(Size slot) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            speedcamServiceProvider.overrideWithValue(svc),
            speedcamAlertProvider.overrideWithValue(FakeSpeedcamAlert()),
            configStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: slot.width,
                  height: slot.height,
                  child: SpeedcamRadarWidget(
                    key: const ValueKey('overlay-size-radar'),
                    variant: SpeedcamRadarVariant.hudCompact,
                    alwaysShow: true,
                    lookOverride: SpeedcamRadarLook.alien,
                    forceDemoDanger: SpeedcamRadarWidget.demoDanger,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final box = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('overlay-size-radar')),
      );
      return box.size;
    }

    final small = await pumpSlot(const Size(168, 123));
    final large = await pumpSlot(const Size(448, 329));
    expect(small.width, closeTo(168, 0.5));
    expect(small.height, closeTo(123, 0.5));
    expect(large.width, closeTo(448, 0.5));
    expect(large.height, closeTo(329, 0.5));
    expect(large.width / small.width, greaterThan(2.0));
    expect(small.width / small.height, closeTo(kSpeedcamCrtPlateAspect, 0.05));
    svc.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/app/speedcam_overlay_app.dart';
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

  testWidgets('0106/0116: Alien CRT fills overlay slot — content scales with window',
      (tester) async {
    // Room for dens1 @ scale 8.0 slot (2240×1643); default 800×600 would clamp.
    await tester.binding.setSurfaceSize(const Size(2560, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    // 0116: prior max footprint ×5 (dens1 @ scale 8.0 → 2240×1643).
    final max5x = await pumpSlot(const Size(2240, 1643));
    expect(small.width, closeTo(168, 0.5));
    expect(small.height, closeTo(123, 0.5));
    expect(large.width, closeTo(448, 0.5));
    expect(large.height, closeTo(329, 0.5));
    expect(max5x.width, closeTo(2240, 0.5));
    expect(max5x.height, closeTo(1643, 0.5));
    expect(large.width / small.width, greaterThan(2.0));
    expect(max5x.width / large.width, closeTo(5.0, 0.02));
    expect(small.width / small.height, closeTo(kSpeedcamCrtPlateAspect, 0.05));
    svc.dispose();
  });

  testWidgets('0129: Default readout scales with overlay window', (
    tester,
  ) async {
    final service = FakeSpeedcamService();
    await service.approachCam(
      FakeSpeedcamService.kFakeBySampleCams.first,
      distanceM: 100,
    );
    final store = SharedPrefsConfigStore();
    await store.load();
    await store.setConfig(
      store.value.copyWith(
        speedcam: store.value.speedcam.copyWith(
          radarLook: SpeedcamRadarLook.defaultLook,
          dhuSystemOverlay: true,
          overlaySizeScale: 1.0,
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(280, 205));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedcamServiceProvider.overrideWithValue(service),
          speedcamAlertProvider.overrideWithValue(FakeSpeedcamAlert()),
          configStoreProvider.overrideWithValue(store),
        ],
        child: const SpeedcamOverlayApp(),
      ),
    );
    await tester.pump();

    final readoutColor = Colors.yellow.withValues(alpha: 0.92);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('speedcam-default-bearing')))
          .style!
          .color,
      readoutColor,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('speedcam-default-distance')))
          .style!
          .color,
      readoutColor,
    );

    final distanceFinder = find.byKey(
      const ValueKey('speedcam-default-distance'),
    );
    final baseFontSize = tester.widget<Text>(distanceFinder).style!.fontSize!;

    await store.setConfig(
      store.value.copyWith(
        speedcam: store.value.speedcam.copyWith(overlaySizeScale: 4.4),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1232, 902));
    await tester.pump();

    final largeFontSize = tester.widget<Text>(distanceFinder).style!.fontSize!;
    expect(largeFontSize / baseFontSize, closeTo(4.4, 0.01));
    service.dispose();
  });
}

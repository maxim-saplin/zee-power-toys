import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

void main() {
  Future<SharedPrefsConfigStore> storeWith(SpeedcamConfig sc) async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsConfigStore();
    await store.load();
    await store.setConfig(AppConfig(speedcam: sc));
    return store;
  }

  testWidgets('Default look shows distance text, not CRT painter', (tester) async {
    final store = await storeWith(const SpeedcamConfig(
      radarLook: SpeedcamRadarLook.defaultLook,
      hudMode: SpeedcamPresenceMode.any,
    ));
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithProviders(
        SpeedcamRadarWidget(
          forceDemoDanger: SpeedcamRadarWidget.demoDanger,
          variant: SpeedcamRadarVariant.hudCompact,
        ),
        store: store,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('speedcam-look-default')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-default-distance')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-look-alien')), findsNothing);
  });

  testWidgets('Alien look paints CRT key, not default text', (tester) async {
    final store = await storeWith(const SpeedcamConfig(
      radarLook: SpeedcamRadarLook.alien,
      hudMode: SpeedcamPresenceMode.any,
    ));
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithProviders(
        SizedBox(
          width: 200,
          height: 200,
          child: SpeedcamRadarWidget(
            forceDemoDanger: SpeedcamRadarWidget.demoDanger,
            variant: SpeedcamRadarVariant.dhuLarge,
            alwaysShow: true,
          ),
        ),
        store: store,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('speedcam-look-alien')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-default-distance')), findsNothing);
  });

  testWidgets('Default HUD idle (no danger) shows nothing', (tester) async {
    final store = await storeWith(const SpeedcamConfig(
      radarLook: SpeedcamRadarLook.defaultLook,
      hudMode: SpeedcamPresenceMode.any,
    ));
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithProviders(
        const SpeedcamRadarWidget(variant: SpeedcamRadarVariant.hudCompact),
        store: store,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('hud-speedcam-radar')), findsNothing);
  });
}

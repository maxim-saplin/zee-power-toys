import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/speedcam_settings_screen.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

void main() {
  testWidgets('DHU radar disk fits in 800x600 without scrolling', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsConfigStore();
    await store.load();

    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithProviders(const SpeedcamSettingsScreen(), store: store),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final radar = find.byKey(const ValueKey('dhu-speedcam-radar'));
    expect(radar, findsOneWidget);

    final box = tester.renderObject<RenderBox>(radar);
    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    expect(bottom, lessThanOrEqualTo(600));
    expect(box.size.height, greaterThanOrEqualTo(140));
  });
}

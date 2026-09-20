import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('durable config mirror', () {
    late Directory tmp;
    late File mirror;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('zee-durable-');
      mirror = File('${tmp.path}/config.json');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('setConfig writes durable mirror', () async {
      final store = SharedPrefsConfigStore(durableMirror: mirror);
      await store.load();
      await store.setConfig(const AppConfig(
        hudEnabled: false,
        speedcam: SpeedcamConfig(dhuRangeM: 1500, soundVolume: 0.5),
      ));
      expect(await mirror.exists(), isTrue);
      final json = jsonDecode(await mirror.readAsString()) as Map<String, dynamic>;
      expect(json['hudEnabled'], isFalse);
      expect((json['speedcam'] as Map)['dhuRangeM'], 1500);
      expect((json['speedcam'] as Map)['soundVolume'], 0.5);
    });

    test('load restores from mirror when prefs empty (reinstall)', () async {
      await mirror.writeAsString(jsonEncode(const AppConfig(
        hudEnabled: false,
        speedcam: SpeedcamConfig(dhuRangeM: 2500, soundVolume: 0.3),
      ).toJson()));

      SharedPreferences.setMockInitialValues({}); // empty prefs = fresh install
      final store = SharedPrefsConfigStore(durableMirror: mirror);
      await store.load();
      expect(store.value.hudEnabled, isFalse);
      expect(store.value.speedcam.dhuRangeM, 2500);
      expect(store.value.speedcam.soundVolume, closeTo(0.3, 1e-9));
    });
  });
}

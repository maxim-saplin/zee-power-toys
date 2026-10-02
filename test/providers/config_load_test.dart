import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/providers/config.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  test(
    'persisted config is available when its provider mounts after load',
    () async {
      const persisted = AppConfig(
        speedcam: SpeedcamConfig(radarLook: SpeedcamRadarLook.alien),
      );
      SharedPreferences.setMockInitialValues({
        'zee.config': jsonEncode(persisted.toJson()),
        'zee.config.schema': 4,
      });

      final store = SharedPrefsConfigStore();
      await store.load();
      final container = ProviderContainer(
        overrides: [configStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(speedcamConfigProvider).radarLook,
        SpeedcamRadarLook.alien,
      );
    },
  );
}

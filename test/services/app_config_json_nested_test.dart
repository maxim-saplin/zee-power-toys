import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  test('AppConfig.fromJson keeps speedcam.radarLook after jsonDecode', () {
    final raw = jsonEncode(const AppConfig(
      speedcam: SpeedcamConfig(radarLook: SpeedcamRadarLook.alien),
    ).toJson());
    // Simulate relay: decode without typed maps
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final cfg = AppConfig.fromJson(Map<String, Object?>.from(decoded));
    expect(cfg.speedcam.radarLook, SpeedcamRadarLook.alien);
  });

  test('fromJsonString round-trips alien look', () {
    final s = jsonEncode(const AppConfig(
      speedcam: SpeedcamConfig(
        radarLook: SpeedcamRadarLook.alien,
        hudRadarEnabled: true,
      ),
    ).toJson());
    final cfg = AppConfig.fromJsonString(s);
    expect(cfg.speedcam.radarLook, SpeedcamRadarLook.alien);
    expect(cfg.speedcam.hudRadarEnabled, isTrue);
  });
}

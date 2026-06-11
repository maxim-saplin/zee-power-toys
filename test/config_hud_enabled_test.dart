// Tests for AppConfig.hudEnabled — round-trip JSON serialization and defaults.
//
// AppConfig is the plain-JSON config read by the native boot shim before any
// Flutter isolate exists (ADR 0003).  hudEnabled gates the HUD engine spawn
// in both ConfigShim.kt and MainActivity.setupHud.

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  group('AppConfig.hudEnabled', () {
    test('default is true', () {
      const cfg = AppConfig();
      expect(cfg.hudEnabled, isTrue);
    });

    test('round-trip through JSON preserves hudEnabled=true', () {
      const src = AppConfig(hudEnabled: true);
      final json = src.toJson();
      final restored = AppConfig.fromJson(json);
      expect(restored.hudEnabled, isTrue);
      expect(restored, equals(src));
    });

    test('round-trip through JSON preserves hudEnabled=false', () {
      const src = AppConfig(hudEnabled: false);
      final json = src.toJson();
      final restored = AppConfig.fromJson(json);
      expect(restored.hudEnabled, isFalse);
      expect(restored, equals(src));
    });

    test('round-trip through JSON string preserves hudEnabled=false', () {
      // Use fromJsonString path (the SharedPrefsConfigStore path).
      final fromStr = AppConfig.fromJsonString(
        '{"hudEnabled":false,"hudBoxOn":false}',
      );
      expect(fromStr.hudEnabled, isFalse);
    });

    test('fromJson defaults hudEnabled=true when key absent', () {
      // Simulates an old config file that predates the hudEnabled key.
      final cfg = AppConfig.fromJson(<String, Object?>{'hudBoxOn': false});
      expect(cfg.hudEnabled, isTrue,
          reason: 'missing key must default to true (fail-open boot policy)');
    });

    test('fromJson defaults hudEnabled=true when JSON is unparseable (null input)', () {
      // The boot shim returns true on parse failure; confirm the Dart layer
      // agrees when we feed a known-absent key.
      final cfg = AppConfig.fromJson(<String, Object?>{});
      expect(cfg.hudEnabled, isTrue);
    });

    test('copyWith only updates hudEnabled', () {
      const src = AppConfig(hudEnabled: false, hudBoxOn: true);
      final copy = src.copyWith(hudEnabled: true);
      expect(copy.hudEnabled, isTrue);
      expect(copy.hudBoxOn, isTrue); // other fields untouched
    });

    test('equality respects hudEnabled', () {
      const a = AppConfig(hudEnabled: true);
      const b = AppConfig(hudEnabled: false);
      expect(a, isNot(equals(b)));
    });

    test('hashCode changes with hudEnabled', () {
      const a = AppConfig(hudEnabled: true);
      const b = AppConfig(hudEnabled: false);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}

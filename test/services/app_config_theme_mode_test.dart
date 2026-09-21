import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  group('AppConfig.themeMode', () {
    test('default is dark', () {
      const cfg = AppConfig();
      expect(cfg.themeMode, 'dark');
    });

    test('JSON round-trip preserves light', () {
      const src = AppConfig(themeMode: 'light');
      final restored = AppConfig.fromJson(src.toJson());
      expect(restored.themeMode, 'light');
      expect(restored, equals(src));
    });

    test('unknown / missing themeMode falls back to dark', () {
      expect(AppConfig.fromJson({}).themeMode, 'dark');
      expect(AppConfig.fromJson({'themeMode': 'auto'}).themeMode, 'dark');
    });

    test('copyWith updates themeMode', () {
      const base = AppConfig();
      expect(base.copyWith(themeMode: 'light').themeMode, 'light');
      expect(
        base.copyWith(themeMode: 'light').copyWith(themeMode: 'dark').themeMode,
        'dark',
      );
    });
  });
}

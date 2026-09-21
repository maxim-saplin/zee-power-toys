import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  group('AppConfig.themeMode', () {
    test('default is auto (follow system)', () {
      const cfg = AppConfig();
      expect(cfg.themeMode, 'auto');
    });

    test('JSON round-trip preserves light / dark / auto', () {
      for (final mode in ['light', 'dark', 'auto']) {
        final src = AppConfig(themeMode: mode);
        final restored = AppConfig.fromJson(src.toJson());
        expect(restored.themeMode, mode);
        expect(restored, equals(src));
      }
    });

    test('missing / unknown / system alias → auto', () {
      expect(AppConfig.fromJson({}).themeMode, 'auto');
      expect(AppConfig.fromJson({'themeMode': 'bogus'}).themeMode, 'auto');
      expect(AppConfig.fromJson({'themeMode': 'system'}).themeMode, 'auto');
    });

    test('copyWith updates themeMode', () {
      const base = AppConfig();
      expect(base.copyWith(themeMode: 'light').themeMode, 'light');
      expect(
        base.copyWith(themeMode: 'light').copyWith(themeMode: 'dark').themeMode,
        'dark',
      );
      expect(
        base.copyWith(themeMode: 'dark').copyWith(themeMode: 'auto').themeMode,
        'auto',
      );
    });
  });
}

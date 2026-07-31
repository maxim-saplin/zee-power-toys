// Tests for Block 0013 — Minimap configuration UI.
//
// Covers:
//   • MinimapConfig round-trip JSON serialization and defaults
//   • enable gated by ynaviAvailable=false (FakeMinimapHost default)
//   • themeFollow 'auto' round-trip and resolution logic
//   • AppConfig round-trip with minimap nested config
//   • ARB parity: every new l10n key exists in both EN and RU generated classes

import 'package:flutter_test/flutter_test.dart';

import 'package:zee_power_toys/l10n/app_localizations_en.dart';
import 'package:zee_power_toys/l10n/app_localizations_ru.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MinimapConfig
  // ---------------------------------------------------------------------------
  group('MinimapConfig', () {
    test('defaults', () {
      const cfg = MinimapConfig();
      expect(cfg.enabled, isFalse);
      expect(cfg.preset, equals('balanced'));
      expect(cfg.advanced, isFalse);
      expect(cfg.widthFrac, isNull);
      expect(cfg.heightFrac, isNull);
      expect(cfg.themeFollow, equals('auto'));
    });

    test('round-trip through JSON — defaults', () {
      const src = MinimapConfig();
      final restored = MinimapConfig.fromJson(src.toJson());
      expect(restored, equals(src));
    });

    test('round-trip through JSON — all fields set', () {
      const src = MinimapConfig(
        enabled: true,
        preset: 'large',
        advanced: true,
        widthFrac: 0.4,
        heightFrac: 0.35,
        themeFollow: 'dark',
      );
      final restored = MinimapConfig.fromJson(src.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.preset, equals('large'));
      expect(restored.advanced, isTrue);
      expect(restored.widthFrac, closeTo(0.4, 0.001));
      expect(restored.heightFrac, closeTo(0.35, 0.001));
      expect(restored.themeFollow, equals('dark'));
    });

    test('fromJson defaults when keys absent', () {
      final cfg = MinimapConfig.fromJson(<String, Object?>{});
      expect(cfg.enabled, isFalse);
      expect(cfg.preset, equals('balanced'));
      expect(cfg.themeFollow, equals('auto'));
    });

    test('copyWith only updates specified fields', () {
      const src = MinimapConfig(enabled: true, preset: 'compact');
      final copy = src.copyWith(themeFollow: 'dark');
      expect(copy.enabled, isTrue);
      expect(copy.preset, equals('compact'));
      expect(copy.themeFollow, equals('dark'));
    });

    test('copyWith can null widthFrac/heightFrac', () {
      const src = MinimapConfig(widthFrac: 0.5, heightFrac: 0.4);
      // Pass explicit null via sentinel.
      final copy = src.copyWith(
        widthFrac: null,
        heightFrac: null,
      );
      expect(copy.widthFrac, isNull);
      expect(copy.heightFrac, isNull);
    });

    test('equality and hashCode', () {
      const a = MinimapConfig(enabled: true, themeFollow: 'dark');
      const b = MinimapConfig(enabled: true, themeFollow: 'dark');
      const c = MinimapConfig(enabled: false, themeFollow: 'dark');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    // themeFollow 'auto' → the resolved brightness depends on system; we can
    // only test the config preserves the 'auto' token and that the screen would
    // use MediaQuery to resolve it.  Here we just confirm round-trip fidelity.
    test('themeFollow=auto round-trip', () {
      const src = MinimapConfig(themeFollow: 'auto');
      expect(MinimapConfig.fromJson(src.toJson()).themeFollow, equals('auto'));
    });

    test('themeFollow=light round-trip', () {
      const src = MinimapConfig(themeFollow: 'light');
      expect(MinimapConfig.fromJson(src.toJson()).themeFollow, equals('light'));
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig round-trip with minimap
  // ---------------------------------------------------------------------------
  group('AppConfig with minimap', () {
    test('default AppConfig has minimap with enabled=false', () {
      const cfg = AppConfig();
      expect(cfg.minimap.enabled, isFalse);
      expect(cfg.minimap.themeFollow, equals('auto'));
    });

    test('round-trip preserves minimap', () {
      const src = AppConfig(
        minimap: MinimapConfig(
          enabled: true,
          preset: 'compact',
          themeFollow: 'dark',
        ),
      );
      final restored = AppConfig.fromJson(src.toJson());
      expect(restored.minimap.enabled, isTrue);
      expect(restored.minimap.preset, equals('compact'));
      expect(restored.minimap.themeFollow, equals('dark'));
    });

    test('fromJson with absent minimap key uses defaults', () {
      final cfg = AppConfig.fromJson(<String, Object?>{});
      expect(cfg.minimap, equals(const MinimapConfig()));
    });

    test('copyWith minimap does not affect other fields', () {
      const src = AppConfig(locale: 'ru');
      final copy = src.copyWith(
        minimap: const MinimapConfig(enabled: true),
      );
      expect(copy.locale, equals('ru'));
      expect(copy.minimap.enabled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Enable gated by YNavi availability
  // ---------------------------------------------------------------------------
  group('FakeMinimapHost.isYnaviAvailable', () {
    test('default is false (emulator/T1 no-mod state)', () async {
      final host = FakeMinimapHost();
      expect(await host.isYnaviAvailable(), isFalse);
    });

    test('can be flipped to true for UI testing', () async {
      final host = FakeMinimapHost();
      host.ynaviAvailable = true;
      expect(await host.isYnaviAvailable(), isTrue);
    });

    test('ynaviAvailable=false: enabling config does not reflect in host.lastEnabled=true intent', () async {
      // Simulates the UI guard: when ynaviAvailable=false, the switch is disabled.
      // We test the host itself stays untouched.
      final host = FakeMinimapHost(); // ynaviAvailable=false by default
      final available = await host.isYnaviAvailable();
      expect(available, isFalse,
          reason: 'toggle should be disabled when not available');
      // The UI would not call host.enable(true) in this state.
      expect(host.lastEnabled, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ARB parity — every new key must exist in both EN and RU
  // ---------------------------------------------------------------------------
  group('ARB parity (EN vs RU)', () {
    final en = AppLocalizationsEn();
    final ru = AppLocalizationsRu();

    test('sectionMinimap', () {
      expect(en.sectionMinimap, isNotEmpty);
      expect(ru.sectionMinimap, isNotEmpty);
    });

    test('sectionMinimapSubtitle', () {
      expect(en.sectionMinimapSubtitle, isNotEmpty);
      expect(ru.sectionMinimapSubtitle, isNotEmpty);
    });

    test('minimapTitle', () {
      expect(en.minimapTitle, isNotEmpty);
      expect(ru.minimapTitle, isNotEmpty);
    });

    test('minimapEnable', () {
      expect(en.minimapEnable, isNotEmpty);
      expect(ru.minimapEnable, isNotEmpty);
    });

    test('minimapYnaviUnavailableHint', () {
      expect(en.minimapYnaviUnavailableHint, isNotEmpty);
      expect(ru.minimapYnaviUnavailableHint, isNotEmpty);
    });

    test('minimapPreset', () {
      expect(en.minimapPreset, isNotEmpty);
      expect(ru.minimapPreset, isNotEmpty);
    });

    test('minimapPresetCompact', () {
      expect(en.minimapPresetCompact, isNotEmpty);
      expect(ru.minimapPresetCompact, isNotEmpty);
    });

    test('minimapPresetBalanced', () {
      expect(en.minimapPresetBalanced, isNotEmpty);
      expect(ru.minimapPresetBalanced, isNotEmpty);
    });

    test('minimapPresetLarge', () {
      expect(en.minimapPresetLarge, isNotEmpty);
      expect(ru.minimapPresetLarge, isNotEmpty);
    });

    test('minimapAdvanced', () {
      expect(en.minimapAdvanced, isNotEmpty);
      expect(ru.minimapAdvanced, isNotEmpty);
    });

    test('minimapWidth', () {
      expect(en.minimapWidth, isNotEmpty);
      expect(ru.minimapWidth, isNotEmpty);
    });

    test('minimapHeight', () {
      expect(en.minimapHeight, isNotEmpty);
      expect(ru.minimapHeight, isNotEmpty);
    });

    test('minimapThemeSection', () {
      expect(en.minimapThemeSection, isNotEmpty);
      expect(ru.minimapThemeSection, isNotEmpty);
    });

    test('minimapThemeAuto', () {
      expect(en.minimapThemeAuto, isNotEmpty);
      expect(ru.minimapThemeAuto, isNotEmpty);
    });

    test('minimapThemeDark', () {
      expect(en.minimapThemeDark, isNotEmpty);
      expect(ru.minimapThemeDark, isNotEmpty);
    });

    test('minimapThemeLight', () {
      expect(en.minimapThemeLight, isNotEmpty);
      expect(ru.minimapThemeLight, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // MinimapConfig.presetFractions / resolvedFracs (Block 0020 minimap wiring)
  // ---------------------------------------------------------------------------
  group('MinimapConfig preset fractions', () {
    test('presetFractions map contains all three presets', () {
      expect(MinimapConfig.presetFractions, contains('compact'));
      expect(MinimapConfig.presetFractions, contains('balanced'));
      expect(MinimapConfig.presetFractions, contains('large'));
    });

    test('resolvedFracs — compact preset', () {
      const cfg = MinimapConfig(preset: 'compact');
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(MinimapConfig.presetFractions['compact']!.$1));
      expect(fracs.$2, equals(MinimapConfig.presetFractions['compact']!.$2));
    });

    test('resolvedFracs — balanced preset (default)', () {
      const cfg = MinimapConfig();
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(MinimapConfig.presetFractions['balanced']!.$1));
      expect(fracs.$2, equals(MinimapConfig.presetFractions['balanced']!.$2));
    });

    test('resolvedFracs — large preset', () {
      const cfg = MinimapConfig(preset: 'large');
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(MinimapConfig.presetFractions['large']!.$1));
      expect(fracs.$2, equals(MinimapConfig.presetFractions['large']!.$2));
    });

    test('resolvedFracs — advanced mode uses manual fracs', () {
      const cfg = MinimapConfig(
        advanced: true,
        widthFrac: 0.45,
        heightFrac: 0.75,
      );
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(0.45));
      expect(fracs.$2, equals(0.75));
    });

    test('resolvedFracs — advanced without fracs falls back to preset', () {
      const cfg = MinimapConfig(advanced: true, preset: 'large');
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(MinimapConfig.presetFractions['large']!.$1));
    });

    test('resolvedFracs — unknown preset falls back to balanced', () {
      const cfg = MinimapConfig(preset: 'unknown-preset');
      final fracs = cfg.resolvedFracs;
      expect(fracs.$1, equals(MinimapConfig.presetFractions['balanced']!.$1));
      expect(fracs.$2, equals(MinimapConfig.presetFractions['balanced']!.$2));
    });

    test('fracs are in valid 0..1 range', () {
      for (final entry in MinimapConfig.presetFractions.entries) {
        expect(entry.value.$1, inInclusiveRange(0.0, 1.0),
            reason: '${entry.key} widthFrac out of range');
        expect(entry.value.$2, inInclusiveRange(0.0, 1.0),
            reason: '${entry.key} heightFrac out of range');
      }
    });
  });
}

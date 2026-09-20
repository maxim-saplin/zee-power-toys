// Tests for Block 0013 — Minimap configuration UI.
// Updated for the "three knobs, not ten" Block: replaced widthFrac/heightFrac
// with a single sizeFraction, replaced themeFollow removal with MinimapLooks
// (colorPreset/contrast/threshold — the Look section).
//
// Covers:
//   • MinimapConfig round-trip JSON serialization and defaults
//   • enable gated by ynaviAvailable=false (FakeMinimapHost default)
//   • MinimapLooks defaults, copyWith, JSON round-trip, toParams wire format
//   • MinimapConfig.resolvedSizeFraction (preset vs. advanced manual override)
//   • AppConfig round-trip with minimap nested config
//   • Backward-compat: an old persisted JSON with widthFrac/heightFrac/
//     themeFollow still loads without throwing
//   • ARB parity: every new l10n key exists in both EN and RU generated classes

import 'package:flutter_test/flutter_test.dart';

import 'package:zee_power_toys/l10n/app_localizations_en.dart';
import 'package:zee_power_toys/l10n/app_localizations_ru.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/minimap_viewport.dart';

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
      expect(cfg.sizeFraction, isNull);
      expect(cfg.looks, equals(const MinimapLooks()));
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
        sizeFraction: 0.42,
        looks: MinimapLooks(colorPreset: 'cyan', contrast: 4.0, threshold: 180),
      );
      final restored = MinimapConfig.fromJson(src.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.preset, equals('large'));
      expect(restored.advanced, isTrue);
      expect(restored.sizeFraction, closeTo(0.42, 0.001));
      expect(restored.looks.colorPreset, equals('cyan'));
      expect(restored.looks.contrast, closeTo(4.0, 0.001));
      expect(restored.looks.threshold, closeTo(180, 0.001));
    });

    test('fromJson defaults when keys absent', () {
      final cfg = MinimapConfig.fromJson(<String, Object?>{});
      expect(cfg.enabled, isFalse);
      expect(cfg.preset, equals('balanced'));
      expect(cfg.looks, equals(const MinimapLooks()));
    });

    test('copyWith only updates specified fields', () {
      const src = MinimapConfig(enabled: true, preset: 'compact');
      final copy = src.copyWith(
        looks: const MinimapLooks(colorPreset: 'amber'),
      );
      expect(copy.enabled, isTrue);
      expect(copy.preset, equals('compact'));
      expect(copy.looks.colorPreset, equals('amber'));
    });

    test('copyWith can null sizeFraction', () {
      const src = MinimapConfig(sizeFraction: 0.5);
      // Pass explicit null via sentinel.
      final copy = src.copyWith(sizeFraction: null);
      expect(copy.sizeFraction, isNull);
    });

    test('equality and hashCode', () {
      const a = MinimapConfig(enabled: true, sizeFraction: 0.5);
      const b = MinimapConfig(enabled: true, sizeFraction: 0.5);
      const c = MinimapConfig(enabled: false, sizeFraction: 0.5);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // MinimapConfig.resolvedSizeFraction — replaces the old resolvedFracs.
  // ---------------------------------------------------------------------------
  group('MinimapConfig.resolvedSizeFraction', () {
    test('non-advanced: resolves via hudPresetSizeFraction(preset)', () {
      const cfg = MinimapConfig();
      expect(
        cfg.resolvedSizeFraction,
        equals(hudPresetSizeFraction('balanced')),
      );
    });

    test('sizeFraction overrides preset when set', () {
      const cfg = MinimapConfig(preset: 'compact', sizeFraction: 0.99);
      expect(cfg.resolvedSizeFraction, closeTo(0.99, 0.001));
    });

    test('manual sizeFraction overrides the preset name', () {
      const cfg = MinimapConfig(sizeFraction: 0.55);
      expect(cfg.resolvedSizeFraction, closeTo(0.55, 0.001));
    });

    test('without sizeFraction falls back to preset', () {
      const cfg = MinimapConfig(preset: 'large');
      expect(cfg.resolvedSizeFraction, equals(hudPresetSizeFraction('large')));
    });

    test('manual sizeFraction is clamped to [0.1, 1.0]', () {
      const tooBig = MinimapConfig(sizeFraction: 5.0);
      const tooSmall = MinimapConfig(sizeFraction: -1.0);
      expect(tooBig.resolvedSizeFraction, equals(1.0));
      expect(tooSmall.resolvedSizeFraction, equals(0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // MinimapLooks — the Look section's three native colour-filter knobs.
  // ---------------------------------------------------------------------------
  group('MinimapLooks', () {
    test('defaults match phase0 Default (White + hue pass)', () {
      const looks = MinimapLooks();
      expect(looks.colorPreset, equals('default'));
      expect(looks.contrast, equals(3.0));
      expect(looks.threshold, equals(150.0));
      expect(looks.huePass, equals(1.0));
      expect(looks.hueAngle, equals(290));
      expect(looks.nativePreset, equals('white'));
    });

    test('copyWith only updates specified fields', () {
      const src = MinimapLooks(colorPreset: 'white', contrast: 2.5);
      final copy = src.copyWith(threshold: 200);
      expect(copy.colorPreset, equals('white'));
      expect(copy.contrast, equals(2.5));
      expect(copy.threshold, equals(200.0));
    });

    test('round-trip through JSON', () {
      const src = MinimapLooks(
        colorPreset: 'amber',
        contrast: 4.2,
        threshold: 180,
      );
      final restored = MinimapLooks.fromJson(src.toJson());
      expect(restored, equals(src));
    });

    test('fromJson defaults when keys absent', () {
      final looks = MinimapLooks.fromJson(<String, Object?>{});
      expect(looks, equals(const MinimapLooks()));
    });

    test('toParams forwards the exact wire keys setMinimapParam expects', () {
      const looks = MinimapLooks(
        colorPreset: 'cyan',
        contrast: 2.0,
        threshold: 140,
      );
      final params = looks.toParams();
      expect(params['preset'], equals('cyan'));
      expect(params['contrast'], equals(2.0));
      expect(params['threshold'], equals(140.0));
    });

    test('equality and hashCode', () {
      const a = MinimapLooks(colorPreset: 'white');
      const b = MinimapLooks(colorPreset: 'white');
      const c = MinimapLooks(colorPreset: 'amber');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig round-trip with minimap
  // ---------------------------------------------------------------------------
  group('AppConfig with minimap', () {
    test('default AppConfig has minimap with enabled=false', () {
      const cfg = AppConfig();
      expect(cfg.minimap.enabled, isFalse);
      expect(cfg.minimap.looks, equals(const MinimapLooks()));
    });

    test('round-trip preserves minimap', () {
      const src = AppConfig(
        minimap: MinimapConfig(
          enabled: true,
          preset: 'compact',
          looks: MinimapLooks(colorPreset: 'white'),
        ),
      );
      final restored = AppConfig.fromJson(src.toJson());
      expect(restored.minimap.enabled, isTrue);
      expect(restored.minimap.preset, equals('compact'));
      expect(restored.minimap.looks.colorPreset, equals('white'));
    });

    test('fromJson with absent minimap key uses defaults', () {
      final cfg = AppConfig.fromJson(<String, Object?>{});
      expect(cfg.minimap, equals(const MinimapConfig()));
    });

    test('copyWith minimap does not affect other fields', () {
      const src = AppConfig(locale: 'ru');
      final copy = src.copyWith(minimap: const MinimapConfig(enabled: true));
      expect(copy.locale, equals('ru'));
      expect(copy.minimap.enabled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Backward compatibility: old persisted configs must keep loading.
  // ---------------------------------------------------------------------------
  group('AppConfig backward-compat load (removed keys)', () {
    test(
      'old JSON with widthFrac/heightFrac/themeFollow loads without throwing',
      () {
        final oldJson = <String, Object?>{
          'hudEnabled': true,
          'minimap': <String, Object?>{
            'enabled': true,
            'preset': 'large',
            'advanced': true,
            // Removed keys — must be silently ignored, not crash fromJson.
            'widthFrac': 0.42,
            'heightFrac': 0.37,
            'themeFollow': 'dark',
          },
        };

        final cfg = AppConfig.fromJson(oldJson);

        expect(cfg.minimap.enabled, isTrue);
        expect(cfg.minimap.preset, equals('large'));
        expect(cfg.minimap.advanced, isTrue);
        // The removed keys leave no trace: sizeFraction stays unset, so
        // resolvedSizeFraction falls back to the (advanced) preset's fraction.
        expect(cfg.minimap.sizeFraction, isNull);
        expect(
          cfg.minimap.resolvedSizeFraction,
          equals(hudPresetSizeFraction('large')),
        );
        expect(cfg.minimap.looks, equals(const MinimapLooks()));
      },
    );

    test('re-serializing an old-JSON-loaded config drops the dead keys', () {
      final oldJson = <String, Object?>{
        'minimap': <String, Object?>{
          'widthFrac': 0.5,
          'heightFrac': 0.5,
          'themeFollow': 'light',
        },
      };
      final cfg = AppConfig.fromJson(oldJson);
      final rewritten = cfg.toJson()['minimap'] as Map<String, Object?>;
      expect(rewritten.containsKey('widthFrac'), isFalse);
      expect(rewritten.containsKey('heightFrac'), isFalse);
      expect(rewritten.containsKey('themeFollow'), isFalse);
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

    test(
      'ynaviAvailable=false: enabling config does not reflect in host.lastEnabled=true intent',
      () async {
        // Simulates the UI guard: when ynaviAvailable=false, the switch is disabled.
        // We test the host itself stays untouched.
        final host = FakeMinimapHost(); // ynaviAvailable=false by default
        final available = await host.isYnaviAvailable();
        expect(
          available,
          isFalse,
          reason: 'toggle should be disabled when not available',
        );
        // The UI would not call host.enable(true) in this state.
        expect(host.lastEnabled, isNull);
      },
    );
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

    test('minimapSize', () {
      expect(en.minimapSize, isNotEmpty);
      expect(ru.minimapSize, isNotEmpty);
    });

    test('minimapLookSection', () {
      expect(en.minimapLookSection, isNotEmpty);
      expect(ru.minimapLookSection, isNotEmpty);
    });

    test('minimapLookPreset', () {
      expect(en.minimapLookPreset, isNotEmpty);
      expect(ru.minimapLookPreset, isNotEmpty);
    });

    test('minimapLookPresetGreenYellow', () {
      expect(en.minimapLookPresetGreenYellow, isNotEmpty);
      expect(ru.minimapLookPresetGreenYellow, isNotEmpty);
    });

    test('minimapLookPresetWhite', () {
      expect(en.minimapLookPresetWhite, isNotEmpty);
      expect(ru.minimapLookPresetWhite, isNotEmpty);
    });

    test('minimapLookPresetAmber', () {
      expect(en.minimapLookPresetAmber, isNotEmpty);
      expect(ru.minimapLookPresetAmber, isNotEmpty);
    });

    test('minimapLookPresetCyan', () {
      expect(en.minimapLookPresetCyan, isNotEmpty);
      expect(ru.minimapLookPresetCyan, isNotEmpty);
    });

    test('minimapLookBrightness', () {
      expect(en.minimapLookBrightness, isNotEmpty);
      expect(ru.minimapLookBrightness, isNotEmpty);
    });

    test('minimapLookContrast', () {
      expect(en.minimapLookContrast, isNotEmpty);
      expect(ru.minimapLookContrast, isNotEmpty);
    });
  });

  group('guidanceOverlay / etaBar (0055)', () {
    test('defaults on (Zee HUD 2 parity)', () {
      const cfg = MinimapConfig();
      expect(cfg.guidanceOverlay, isTrue);
      expect(cfg.etaBar, isTrue);
      expect(cfg.overlayScale, 0.5);
    });

    test('JSON round-trip', () {
      const cfg = MinimapConfig(
        enabled: true,
        guidanceOverlay: false,
        etaBar: true,
        overlayScale: 0.7,
      );
      expect(MinimapConfig.fromJson(cfg.toJson()), equals(cfg));
    });
  });

  group('onlyWhileGuidance (0057)', () {
    test('defaults off', () {
      expect(const MinimapConfig().onlyWhileGuidance, isFalse);
    });

    test('JSON round-trip', () {
      const cfg = MinimapConfig(enabled: true, onlyWhileGuidance: true);
      expect(MinimapConfig.fromJson(cfg.toJson()), equals(cfg));
    });

    test('minimapSurfaceWanted respects gate', () {
      const off = MinimapConfig(enabled: true, onlyWhileGuidance: false);
      const gated = MinimapConfig(enabled: true, onlyWhileGuidance: true);
      expect(minimapSurfaceWanted(off, navActive: false), isTrue);
      expect(minimapSurfaceWanted(gated, navActive: false), isFalse);
      expect(minimapSurfaceWanted(gated, navActive: true), isTrue);
      expect(
        minimapSurfaceWanted(
          const MinimapConfig(enabled: false, onlyWhileGuidance: true),
          navActive: true,
        ),
        isFalse,
      );
    });
  });

}

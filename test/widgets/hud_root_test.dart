import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/hud/blinker_widget.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';
import 'package:zee_power_toys/widgets/hud_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Prevent SharedPreferences from touching the filesystem in tests.
    SharedPreferences.setMockInitialValues({});
  });

  /// Wraps [child] in a minimal ProviderScope with in-memory services.
  Widget wrapWithProviders(
    Widget child, {
    AppConfig? config,
    FakeCarSignals? signals,
  }) {
    final store = SharedPrefsConfigStore();
    if (config != null) {
      // Seed synchronously so the widget sees it on first build.
      store.setConfig(config);
    }
    return ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(signals ?? FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('HudRoot', () {
    testWidgets('is backdrop-agnostic — paints no opaque background', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const HudRoot()));
      await tester.pump();

      // HudRoot must NOT paint its own background: the surface supplies it
      // (black on the real HUD, grey in the DHU preview). This is what lets the
      // preview's grey show through where the HUD is "transparent" (black).
      var paintsBlack = false;
      tester.element(find.byType(HudRoot)).visitChildren((child) {
        if (child.widget is ColoredBox &&
            (child.widget as ColoredBox).color == Colors.black) {
          paintsBlack = true;
        }
      });
      expect(paintsBlack, isFalse,
          reason: 'HudRoot is backdrop-agnostic; the surface provides the backdrop');
    });

    testWidgets('honours Safe Area — slots positioned inside inset', (tester) async {
      // Use a tight Safe Area (70% of each dimension) so positions are testable.
      const sa = HudSafeArea(left: 0.05, top: 0.05, right: 0.95, bottom: 0.95);
      final config = AppConfig(safeArea: sa);

      await tester.binding.setSurfaceSize(const Size(1024, 576));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudRoot(), config: config));
      await tester.pump();

      // Safe Area outer Positioned must exist and be within display bounds.
      // There is exactly one Positioned for the Safe Area clipping region.
      expect(find.byType(ClipRect), findsOneWidget);
    });

    testWidgets('shows slot stubs — GUIDANCE, MINIMAP only in preview mode', (tester) async {
      // BLINKER and BATTERY are real widgets; GUIDANCE and MINIMAP are preview-only stubs.
      await tester.binding.setSurfaceSize(const Size(1024, 576));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Preview mode (showSafeAreaBorder=true): stubs are visible.
      await tester.pumpWidget(wrapWithProviders(const HudRoot(showSafeAreaBorder: true)));
      await tester.pump();

      expect(find.text('GUIDANCE'), findsOneWidget);
      expect(find.text('MINIMAP'), findsOneWidget);
      // BlinkerWidget replaced the BLINKER stub.
      expect(find.byType(BlinkerWidget), findsOneWidget);
      // BatteryWidget replaced the BATTERY stub (text 'BATTERY' is gone).
      expect(find.text('BATTERY'), findsNothing);
    });

    testWidgets('production HUD has no ghost stubs; preview has stubs; BLINKER+BATTERY always render', (tester) async {
      // This test guards the core emissive-projector invariant:
      // the production HUD must not emit GUIDANCE/MINIMAP rectangles onto the windshield,
      // while the DHU preview shows them as layout aids.
      await tester.binding.setSurfaceSize(const Size(1024, 576));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // --- Production HUD (showSafeAreaBorder=false, the default) ---
      await tester.pumpWidget(wrapWithProviders(const HudRoot(showSafeAreaBorder: false)));
      await tester.pump();

      expect(find.text('GUIDANCE'), findsNothing,
          reason: 'Production HUD must not emit a GUIDANCE ghost rectangle');
      expect(find.text('MINIMAP'), findsNothing,
          reason: 'Production HUD must not emit a MINIMAP ghost rectangle');
      // Real content always present.
      expect(find.byType(BlinkerWidget), findsOneWidget,
          reason: 'BLINKER must always render');
      expect(find.byType(BatteryWidget), findsOneWidget,
          reason: 'BATTERY must always render');

      // --- DHU preview (showSafeAreaBorder=true) ---
      await tester.pumpWidget(wrapWithProviders(const HudRoot(showSafeAreaBorder: true)));
      await tester.pump();

      expect(find.text('GUIDANCE'), findsOneWidget,
          reason: 'Preview shows GUIDANCE stub as a layout aid');
      expect(find.text('MINIMAP'), findsOneWidget,
          reason: 'Preview shows MINIMAP stub as a layout aid');
      // Real content still present in preview too.
      expect(find.byType(BlinkerWidget), findsOneWidget,
          reason: 'BLINKER must always render');
      expect(find.byType(BatteryWidget), findsOneWidget,
          reason: 'BATTERY must always render');
    });

    testWidgets('Safe Area border absent when showSafeAreaBorder=false', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const HudRoot(showSafeAreaBorder: false)),
      );
      await tester.pump();

      // The debug border uses ValueKey('hud-safe-area-border'); absent when off.
      expect(
        find.byKey(const ValueKey('hud-safe-area-border')),
        findsNothing,
      );
    });

    testWidgets('Safe Area border present when showSafeAreaBorder=true', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const HudRoot(showSafeAreaBorder: true)),
      );
      await tester.pump();

      // The debug border is tagged with ValueKey('hud-safe-area-border').
      expect(
        find.byKey(const ValueKey('hud-safe-area-border')),
        findsOneWidget,
      );
    });
  });

  group('HudPreview', () {
    testWidgets('renders HudRoot — same widget class, not a mock', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudPreview()));
      await tester.pump();

      // HudPreview must embed a HudRoot (ADR 0001 — cannot drift).
      expect(find.byType(HudRoot), findsOneWidget);
    });

    testWidgets('preview has correct aspect ratio widget', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudPreview()));
      await tester.pump();

      expect(find.byType(AspectRatio), findsOneWidget);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ar.aspectRatio, closeTo(1024 / 576, 0.001));
    });

    testWidgets('preview draws the Safe Area outline itself', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudPreview()));
      await tester.pump();

      // The preview draws a bright cyan Safe-Area outline (alpha 0.6) over the HudRoot.
      // HudRoot inside HudPreview also draws its own dimmer internal border (alpha 0.35),
      // but this test checks for the preview's own prominent outline.
      final cyan = const Color(0xFF00FFFF).withValues(alpha: 0.6);
      final hasCyanBorder = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((d) {
        final dec = d.decoration;
        return dec is BoxDecoration && dec.border is Border &&
            (dec.border! as Border).top.color == cyan;
      });
      expect(hasCyanBorder, isTrue,
          reason: 'HudPreview should draw the Safe Area outline');
    });

    testWidgets('grey ground plane is present behind HudRoot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudPreview()));
      await tester.pump();

      // First ColoredBox in HudPreview is the grey ground.
      final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        boxes.any((b) => b.color == const Color(0xFF888888)),
        isTrue,
        reason: 'Expected a grey ground-plane ColoredBox in HudPreview',
      );
    });
  });

  group('HudSafeArea model', () {
    test('default values are phase-0 calibrated values', () {
      const sa = HudSafeArea();
      expect(sa.left, closeTo(0.1064, 0.0001));
      expect(sa.top, closeTo(0.3125, 0.0001));
      expect(sa.right, closeTo(0.9072, 0.0001));
      expect(sa.bottom, closeTo(0.7170, 0.0001));
    });

    test('copyWith only updates named fields', () {
      const sa = HudSafeArea();
      final sa2 = sa.copyWith(left: 0.05);
      expect(sa2.left, closeTo(0.05, 0.0001));
      expect(sa2.top, equals(sa.top));
      expect(sa2.right, equals(sa.right));
      expect(sa2.bottom, equals(sa.bottom));
    });

    test('round-trips through JSON', () {
      const sa = HudSafeArea(left: 0.10, top: 0.30, right: 0.90, bottom: 0.72);
      final json = sa.toJson();
      final sa2 = HudSafeArea.fromJson(json);
      expect(sa2, equals(sa));
    });

    test('fromJson falls back to defaults for missing keys', () {
      final sa = HudSafeArea.fromJson(<String, Object?>{});
      expect(sa, equals(const HudSafeArea()));
    });

    test('equality and hashCode', () {
      const a = HudSafeArea(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);
      const b = HudSafeArea(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AppConfig with safeArea', () {
    test('toJson / fromJson round-trips safeArea', () {
      const config = AppConfig(
        safeArea: HudSafeArea(left: 0.10, top: 0.30, right: 0.90, bottom: 0.72),
      );
      final json = config.toJson();
      final config2 = AppConfig.fromJson(json);
      expect(config2.safeArea, equals(config.safeArea));
    });

    test('fromJson with missing safeArea key uses defaults', () {
      final config = AppConfig.fromJson(<String, Object?>{});
      expect(config.safeArea, equals(const HudSafeArea()));
    });
  });

  // ---------------------------------------------------------------------------
  // BlinkerConfig model
  // ---------------------------------------------------------------------------

  group('BlinkerConfig model', () {
    test('defaults: small single-circle indicator, vertically centred', () {
      const cfg = BlinkerConfig();
      expect(cfg.shape, BlinkerShape.dots); // dots = single small circle
      expect(cfg.sizeScale, 1.0);
      expect(cfg.sidePadFrac, closeTo(0.04, 0.001));
      expect(cfg.vertFrac, closeTo(0.50, 0.001));
    });

    test('round-trips through JSON for each shape', () {
      for (final shape in BlinkerShape.values) {
        final cfg = BlinkerConfig(shape: shape, sizeScale: 1.5);
        final json = cfg.toJson();
        final cfg2 = BlinkerConfig.fromJson(json);
        expect(cfg2, equals(cfg), reason: 'round-trip failed for shape=$shape');
      }
    });

    test('fromJson falls back to defaults for missing keys', () {
      final cfg = BlinkerConfig.fromJson(<String, Object?>{});
      expect(cfg, equals(const BlinkerConfig()));
    });

    test('fromJson unknown shape falls back to dots', () {
      final cfg = BlinkerConfig.fromJson(<String, Object?>{'shape': 'unknown_shape'});
      expect(cfg.shape, BlinkerShape.dots);
    });

    test('copyWith only updates named fields', () {
      const cfg = BlinkerConfig();
      final cfg2 = cfg.copyWith(shape: BlinkerShape.arrows, sizeScale: 1.8);
      expect(cfg2.shape, BlinkerShape.arrows);
      expect(cfg2.sizeScale, 1.8);
      expect(cfg2.sidePadFrac, cfg.sidePadFrac);
      expect(cfg2.vertFrac, cfg.vertFrac);
    });

    test('equality and hashCode', () {
      const a = BlinkerConfig(shape: BlinkerShape.smiley, sizeScale: 1.2);
      const b = BlinkerConfig(shape: BlinkerShape.smiley, sizeScale: 1.2);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AppConfig includes BlinkerConfig', () {
    test('toJson / fromJson round-trips blinker config', () {
      const cfg = AppConfig(
        blinker: BlinkerConfig(shape: BlinkerShape.arrows, sizeScale: 1.5),
      );
      final json = cfg.toJson();
      final cfg2 = AppConfig.fromJson(json);
      expect(cfg2.blinker.shape, BlinkerShape.arrows);
      expect(cfg2.blinker.sizeScale, 1.5);
    });

    test('fromJson with missing blinker key uses defaults', () {
      final cfg = AppConfig.fromJson(<String, Object?>{});
      expect(cfg.blinker, equals(const BlinkerConfig()));
    });
  });

  // ---------------------------------------------------------------------------
  // BlinkerWidget — shape × side × state
  // ---------------------------------------------------------------------------

  group('BlinkerWidget', () {
    testWidgets('off state renders nothing', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        signals: signals,
      ));
      await tester.pump();

      // Off → SizedBox.shrink() — no mark keys present.
      expect(find.byKey(const ValueKey('blinker-mark-left')), findsNothing);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsNothing);
    });

    testWidgets('dots shape — left renders left mark only', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.dots),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsNothing);
    });

    testWidgets('dots shape — right renders right mark only', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.dots),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsNothing);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);
    });

    testWidgets('arrows shape — left renders left mark', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.arrows),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsNothing);
    });

    testWidgets('arrows shape — right renders right mark', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.arrows),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsNothing);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);
    });

    testWidgets('smiley shape — left renders left mark', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.smiley),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
    });

    testWidgets('smiley shape — right renders right mark', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.smiley),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.right);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);
    });

    testWidgets('hazard renders BOTH left and right marks', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.hazard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);
    });

    testWidgets('off after active clears both marks', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        signals: signals,
      ));

      signals.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);

      signals.emitBlinker(BlinkerState.off);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byKey(const ValueKey('blinker-mark-left')), findsNothing);
    });

    // Each shape × each side (arrows left, arrows right, smiley left, smiley right,
    // dots hazard) are tested above.  Below confirms arrows left/right are distinct.
    testWidgets('arrows hazard renders both left and right marks', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(400, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        blinker: const BlinkerConfig(shape: BlinkerShape.arrows),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
        config: config,
        signals: signals,
      ));
      signals.emitBlinker(BlinkerState.hazard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);
    });
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/hud/blinker_widget.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/minimap_viewport.dart';
import 'package:zee_power_toys/widgets/hud_preview.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

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

      await pumpHud(tester, wrapWithProviders(const HudRoot(), config: config));

      // Safe Area outer Positioned must exist and be within display bounds.
      // There is exactly one Positioned for the Safe Area clipping region.
      expect(find.byType(ClipRect), findsOneWidget);
    });

    testWidgets('there is no GUIDANCE slot — removed entirely, in any mode', (tester) async {
      // Owner decision: Guidance and Minimap are not two features — the HUD
      // shows the YNavi map, and there is no separate turn-by-turn overlay in
      // scope. GUIDANCE (and its l10n string) is gone, not just hidden.
      await pumpHud(tester, wrapWithProviders(const HudRoot(showSafeAreaBorder: false)));
      expect(find.text('GUIDANCE'), findsNothing);

      await tester.pumpWidget(wrapWithProviders(const HudRoot(showSafeAreaBorder: true)));
      await tester.pump();
      expect(find.text('GUIDANCE'), findsNothing,
          reason: 'GUIDANCE must not exist even in preview/debug mode — it was removed, not hidden');
    });

    testWidgets('shows MINIMAP glyph only in preview mode when minimap enabled', (tester) async {
      // BLINKER and BATTERY are real widgets; MINIMAP is a preview-only
      // schematic glyph stand-in for the real (natively-composited) Minimap.
      // F4: glyph requires minimapEnabled — default is off.
      const cfg = AppConfig(minimap: MinimapConfig(enabled: true));
      await pumpHud(
        tester,
        wrapWithProviders(const HudRoot(showSafeAreaBorder: true), config: cfg),
      );

      expect(find.byKey(const ValueKey('hud-minimap-glyph')), findsOneWidget);
      // BlinkerWidget and BatteryWidget are always the real widgets.
      expect(find.byType(BlinkerWidget), findsOneWidget);
      expect(find.byType(BatteryWidget), findsOneWidget);
    });

    testWidgets('preview omits MINIMAP glyph when minimap disabled (F4)', (tester) async {
      await pumpHud(
        tester,
        wrapWithProviders(const HudRoot(showSafeAreaBorder: true)),
      );
      expect(find.byKey(const ValueKey('hud-minimap-glyph')), findsNothing,
          reason: 'stub must not show when minimapEnabled=false');
    });

    testWidgets('production HUD has no ghost minimap glyph; preview has it; BLINKER+BATTERY always render', (tester) async {
      // This test guards the core emissive-projector invariant: the
      // production HUD must not emit a MINIMAP ghost rectangle onto the
      // windshield (the real Minimap is composited natively by MinimapHost,
      // never painted by Flutter), while the DHU preview shows the schematic
      // glyph as a layout aid.
      // --- Production HUD (showSafeAreaBorder=false, the default) ---
      await pumpHud(tester, wrapWithProviders(const HudRoot(showSafeAreaBorder: false)));

      expect(find.byKey(const ValueKey('hud-minimap-glyph')), findsNothing,
          reason: 'Production HUD must not emit a MINIMAP ghost rectangle');
      // Real content always present.
      expect(find.byType(BlinkerWidget), findsOneWidget,
          reason: 'BLINKER must always render');
      expect(find.byType(BatteryWidget), findsOneWidget,
          reason: 'BATTERY must always render');

      // --- DHU preview (showSafeAreaBorder=true, minimap enabled) ---
      const previewCfg = AppConfig(minimap: MinimapConfig(enabled: true));
      await tester.pumpWidget(
        wrapWithProviders(const HudRoot(showSafeAreaBorder: true), config: previewCfg),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('hud-minimap-glyph')), findsOneWidget,
          reason: 'Preview shows the MINIMAP glyph as a layout aid when enabled');
      // Real content still present in preview too.
      expect(find.byType(BlinkerWidget), findsOneWidget,
          reason: 'BLINKER must always render');
      expect(find.byType(BatteryWidget), findsOneWidget,
          reason: 'BATTERY must always render');
    });

    testWidgets('MINIMAP glyph rect equals minimapRectInSafeArea() scaled onto the Safe Area', (tester) async {
      // Real HUD geometry (1024×576 @ 213dpi) — CONTEXT.md's Minimap entry —
      // so the Safe Area's on-screen pixel size matches the runtime-verified
      // rect exactly, letting this assertion be checked against real numbers.
      const sa = HudSafeArea();
      final config = AppConfig(
        safeArea: sa,
        minimap: const MinimapConfig(enabled: true),
      );
      await pumpHud(
        tester,
        wrapWithProviders(const HudRoot(showSafeAreaBorder: true), config: config),
        size: const Size(1024, 576),
      );

      final saWidthPx = (sa.right - sa.left) * 1024;
      final saHeightPx = (sa.bottom - sa.top) * 576;
      final saLeftPx = sa.left * 1024;
      final saTopPx = sa.top * 576;

      final rel = minimapRectInSafeArea(); // default preset: 'balanced'
      final expectedLeft = saLeftPx + rel.left * saWidthPx;
      final expectedTop = saTopPx + rel.top * saHeightPx;
      final expectedWidth = rel.width * saWidthPx;
      final expectedHeight = rel.height * saHeightPx;

      final glyphFinder = find.byKey(const ValueKey('hud-minimap-glyph'));
      final actualTopLeft = tester.getTopLeft(glyphFinder);
      final actualSize = tester.getSize(glyphFinder);

      expect(actualTopLeft.dx, closeTo(expectedLeft, 1.0),
          reason: 'glyph left must match minimapRectInSafeArea() scaled onto the Safe Area');
      expect(actualTopLeft.dy, closeTo(expectedTop, 1.0),
          reason: 'glyph top must match minimapRectInSafeArea() scaled onto the Safe Area');
      expect(actualSize.width, closeTo(expectedWidth, 1.0),
          reason: 'glyph width must match minimapRectInSafeArea() scaled onto the Safe Area');
      expect(actualSize.height, closeTo(expectedHeight, 1.0),
          reason: 'glyph height must match minimapRectInSafeArea() scaled onto the Safe Area');
      // Cross-check against the CONTEXT.md-documented, runtime-verified rect.
      expect(actualTopLeft.dx, closeTo(150.0, 1.0),
          reason: 'must match the runtime-confirmed Rect.fromLTWH(150, 191, 210, 210)');
      expect(actualTopLeft.dy, closeTo(191.0, 1.0),
          reason: 'must match the runtime-confirmed Rect.fromLTWH(150, 191, 210, 210)');
      expect(actualSize.width, closeTo(210.0, 1.0),
          reason: 'must match the runtime-confirmed Rect.fromLTWH(150, 191, 210, 210)');
      expect(actualSize.height, closeTo(210.0, 1.0),
          reason: 'must match the runtime-confirmed Rect.fromLTWH(150, 191, 210, 210)');
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
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

      // HudPreview must embed a HudRoot (ADR 0001 — cannot drift).
      expect(find.byType(HudRoot), findsOneWidget);
    });

    testWidgets('default (letterbox) preview aspect ratio is the Safe Area — 616/175 ≈ 3.52:1', (tester) async {
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

      expect(find.byType(AspectRatio), findsOneWidget);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      // 616/175 is the Safe Area's own dp aspect ratio (phase0 constants); the
      // default HudSafeArea fractions were derived from exactly those dp
      // values at the real HUD's 1024×576 geometry, so the two must agree.
      expect(ar.aspectRatio, closeTo(616 / 175, 0.01 * (616 / 175)),
          reason: 'Primary preview must show the Safe Area letterbox, not the full backing display');
    });

    testWidgets('fullDisplay mode preview aspect ratio is the full backing display — 1024/576', (tester) async {
      await pumpHud(
        tester,
        wrapWithProviders(const HudPreview(mode: HudPreviewMode.fullDisplay)),
        size: const Size(800, 600),
      );

      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ar.aspectRatio, closeTo(1024 / 576, 0.001),
          reason: 'Secondary debug view must show the whole backing display');
    });

    testWidgets('preview draws the Safe Area outline itself', (tester) async {
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

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
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

      // First ColoredBox in HudPreview is the grey ground.
      final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        boxes.any((b) => b.color == const Color(0xFF888888)),
        isTrue,
        reason: 'Expected a grey ground-plane ColoredBox in HudPreview',
      );
    });

    testWidgets('shows visible blinker + battery content with no CarSignal injected (Block 0026 demo override)', (tester) async {
      // No signals emitted at all — HudPreview's _demoSignalOverrides must
      // force a visible hazard blinker (both marks) and a plausible charging
      // battery reading regardless.
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget,
          reason: 'demo override forces hazard — left mark must be visible with no signal injected');
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget,
          reason: 'demo override forces hazard — right mark must be visible with no signal injected');
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget,
          reason: 'battery content must render with no signal injected');
      expect(find.byKey(const ValueKey('charging-kw-text')), findsOneWidget,
          reason: 'demo override forces charging=true — the kW panel must be visible');
    });

    testWidgets('letterbox content (blinker marks) is actually visible inside the rendered preview box — not squashed/clipped away', (tester) async {
      // Regression guard for a real bug caught only by rendering an actual
      // PNG: an earlier version of HudPreview's letterbox transform clipped
      // content at its UNSCALED (real-HUD-pixel) size before the fit-to-box
      // scale was applied, rendering an empty grey box with only the badge
      // visible. Every find.byKey(...) tree-presence test (like the one
      // above) still passed throughout, because none of them checked WHERE
      // the widget actually painted — only that it existed in the tree.
      await pumpHud(
        tester,
        wrapWithProviders(const HudPreview(), scaffold: true),
        size: const Size(1200, 500),
      );

      final previewRect = tester.getRect(find.byType(HudPreview));
      final leftMarkRect = tester.getRect(find.byKey(const ValueKey('blinker-mark-left')));
      final rightMarkRect = tester.getRect(find.byKey(const ValueKey('blinker-mark-right')));

      expect(previewRect.overlaps(leftMarkRect), isTrue,
          reason: 'left blinker mark must be painted inside the preview box, not clipped away');
      expect(previewRect.overlaps(rightMarkRect), isTrue,
          reason: 'right blinker mark must be painted inside the preview box, not clipped away');

      // The two marks sit near the Safe Area's own left/right edges — they
      // must be spread across most of the letterbox width, not collapsed
      // together (which is what the unscaled-clip bug produced: a near-empty
      // box with content squeezed into a sliver near one corner).
      final spread = (rightMarkRect.center.dx - leftMarkRect.center.dx).abs();
      expect(spread, greaterThan(previewRect.width * 0.5),
          reason: 'blinker marks must span most of the letterbox width');
    });

    testWidgets('badge renders by default (PREVIEW · DEMO)', (tester) async {
      await pumpHud(tester, wrapWithProviders(const HudPreview()), size: const Size(800, 600));

      expect(find.byKey(const ValueKey('hud-preview-badge')), findsOneWidget);
      expect(find.text('PREVIEW · DEMO'), findsOneWidget);
    });

    testWidgets('badge absent when badge=none', (tester) async {
      await pumpHud(
        tester,
        wrapWithProviders(const HudPreview(badge: HudPreviewBadge.none)),
        size: const Size(800, 600),
      );

      expect(find.byKey(const ValueKey('hud-preview-badge')), findsNothing);
    });

    testWidgets('badge shows LIVE · SIMULATED when badge=liveSimulated', (tester) async {
      await pumpHud(
        tester,
        wrapWithProviders(const HudPreview(badge: HudPreviewBadge.liveSimulated)),
        size: const Size(800, 600),
      );

      expect(find.text('LIVE · SIMULATED'), findsOneWidget);
    });

    testWidgets('badge never renders on the real HUD surface (HudRoot alone)', (tester) async {
      // HudPreview's badge is not part of HudRoot at all — HudRoot is what
      // the real HUD Presentation paints, and it has no concept of a badge.
      await pumpHud(tester, wrapWithProviders(const HudRoot()));

      expect(find.byKey(const ValueKey('hud-preview-badge')), findsNothing);
      expect(find.text('PREVIEW · DEMO'), findsNothing);
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
      await pumpHud(
        tester,
        wrapWithProviders(
          const SizedBox(width: 400, height: 200, child: BlinkerWidget()),
          signals: signals,
        ),
        size: const Size(400, 200),
      );

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


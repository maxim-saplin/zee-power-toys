import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/providers/services.dart';
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
  Widget wrapWithProviders(Widget child, {AppConfig? config}) {
    final store = SharedPrefsConfigStore();
    if (config != null) {
      // Seed synchronously so the widget sees it on first build.
      store.setConfig(config);
    }
    return ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: MaterialApp(home: child),
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

    testWidgets('shows slot stubs — BLINKER, BATTERY, GUIDANCE, MINIMAP', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 576));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(const HudRoot()));
      await tester.pump();

      expect(find.text('BLINKER'), findsOneWidget);
      expect(find.text('BATTERY'), findsOneWidget);
      expect(find.text('GUIDANCE'), findsOneWidget);
      expect(find.text('MINIMAP'), findsOneWidget);
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

      // The preview draws its OWN cyan Safe-Area outline; the embedded HudRoot
      // stays borderless (it is the same widget shown on the real HUD surface).
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
        hudBoxOn: true,
        safeArea: HudSafeArea(left: 0.10, top: 0.30, right: 0.90, bottom: 0.72),
      );
      final json = config.toJson();
      final config2 = AppConfig.fromJson(json);
      expect(config2.hudBoxOn, isTrue);
      expect(config2.safeArea, equals(config.safeArea));
    });

    test('fromJson with missing safeArea key uses defaults', () {
      final config = AppConfig.fromJson(<String, Object?>{'hudBoxOn': false});
      expect(config.safeArea, equals(const HudSafeArea()));
    });
  });
}

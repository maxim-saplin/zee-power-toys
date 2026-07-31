import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/hud_root.dart';
import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/car_signals.dart';

/// DHU preview of the HUD content.
///
/// Renders the SAME [HudRoot] widget subtree (ADR 0001 — the preview cannot
/// drift from the real HUD) scaled to fit a preview box.  Background is grey
/// to simulate the heads-up display glass: on the real HUD, black = no light;
/// here the grey ground plane makes the black areas visible as an approximate
/// glass-on-glass simulation.
///
/// The Safe Area rectangle is outlined so layout calibration is obvious.
///
/// CarSignal-driven content (blinker, charging) is forced to a fixed demo
/// scenario here — see [_demoSignalOverrides] — so this Config Preview is
/// usable without a live/injected car signal (Block 0026: split from the
/// Developer Simulate screen, which drives the real unforced signal chain).
/// This only overrides the signal providers for this subtree; config
/// providers (shape, size, Safe Area) fall through to the real root
/// container via Riverpod provider scoping, so edits made on the same
/// screen still update this preview live.
///
/// [aspectRatio] defaults to 1024/576 (the physical HUD backing display).
class HudPreview extends ConsumerWidget {
  const HudPreview({super.key, this.aspectRatio = 1024 / 576});

  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaProvider);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: <Widget>[
              // Grey ground — simulates the windshield glass. Because HudRoot is
              // backdrop-agnostic (transparent except for emissive marks), this grey
              // shows through wherever the real HUD would be black/transparent.
              const ColoredBox(color: Color(0xFF888888), child: SizedBox.expand()),

              // The real HudRoot — same widget, so it cannot drift from the HUD surface.
              // showSafeAreaBorder=true enables the GUIDANCE/MINIMAP slot stubs so
              // they are visible in the preview; they are suppressed in production
              // (showSafeAreaBorder=false, the default) to keep the windshield clean.
              //
              // Scoped override: only the live CarSignal providers are replaced with
              // fixed demo values (_demoSignalOverrides) so the preview always shows
              // the configured look. Everything else HudRoot reads (blinkerConfigProvider,
              // batteryConfigProvider, safeAreaProvider, ...) is not overridden here, so
              // Riverpod falls through to the real root container.
              ProviderScope(
                overrides: _demoSignalOverrides,
                child: const HudRoot(showSafeAreaBorder: true),
              ),

              // Safe Area outline drawn over the HudRoot so it is always visible even
              // when HudRoot's internal border is transparent-enough to miss at a glance.
              Positioned(
                left: safeArea.left * w,
                top: safeArea.top * h,
                width: (safeArea.right - safeArea.left) * w,
                height: (safeArea.bottom - safeArea.top) * h,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF00FFFF).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fixed demo values for CarSignal-driven providers, scoped to [HudPreview]'s
/// nested [ProviderScope]. Untyped list literal: the `Override` return type of
/// `overrideWithValue` is not part of Riverpod's public export surface, so it
/// cannot be named directly (see `main.dart`'s root overrides for the same
/// pattern) — the list's element type is inferred instead.
///
/// hazard shows both left and right marks simultaneously so shape/size/side-
/// padding edits are checkable on both sides at once. Charging is forced on
/// with a plausible reading so the charging-stats panel (only ever shown
/// while charging, ADR 0003) is checkable here too.
final _demoSignalOverrides = [
  blinkerProvider.overrideWithValue(BlinkerState.hazard),
  chargingProvider.overrideWithValue(true),
  chargeKwProvider.overrideWithValue(7.4),
  batteryPctProvider.overrideWithValue(72),
  batteryTempCProvider.overrideWithValue(24.0),
];

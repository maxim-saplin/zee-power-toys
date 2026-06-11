import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/hud_root.dart';
import '../providers/config.dart';

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
              const HudRoot(),

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

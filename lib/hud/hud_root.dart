import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../services/config_store.dart';
import 'blinker_widget.dart';

/// The root of the HUD widget subtree.
///
/// Emissive rendering rule: this widget is **backdrop-agnostic** — it draws
/// only the bright HUD marks and is otherwise transparent. The *surface*
/// supplies the backdrop: the real HUD paints pure black behind it (black
/// pixels emit no light on the projector and read as transparent on the
/// windshield), while the DHU preview paints grey so those "transparent"
/// regions show as glass. This is what lets the preview match the real HUD
/// without drift. Never paint a light background, card, or panel here.
///
/// Content is clipped and positioned inside the [HudSafeArea] rectangle.
/// The Safe Area is the sub-rectangle of the backing display actually visible
/// through the projector optics.
///
/// Slots: [blinker] (real content), [battery], [guidance], [minimap] (stubs).
/// The BLINKER layer spans the full Safe Area so hazard can render both sides;
/// marks are positioned at the edges by [BlinkerWidget] via its own layout.
///
/// [showSafeAreaBorder] draws a faint outline of the Safe Area (debug aid;
/// disabled in production by default, enabled in the DHU preview).
class HudRoot extends ConsumerWidget {
  const HudRoot({super.key, this.showSafeAreaBorder = false});

  final bool showSafeAreaBorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaProvider);

    // No background fill — the surface (black HUD / grey preview) provides it.
    return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final saLeft = safeArea.left * w;
          final saTop = safeArea.top * h;
          final saRight = safeArea.right * w;
          final saBottom = safeArea.bottom * h;
          final saWidth = saRight - saLeft;
          final saHeight = saBottom - saTop;

          return Stack(
            children: <Widget>[
              // Safe Area clip — all HUD content lives inside here.
              Positioned(
                left: saLeft,
                top: saTop,
                width: saWidth,
                height: saHeight,
                child: ClipRect(
                  child: _HudSlots(saWidth: saWidth, saHeight: saHeight),
                ),
              ),

              // Faint Safe Area border — debug visual; not visible on the
              // physical HUD (it is part of the DHU preview, not the HUD image).
              if (showSafeAreaBorder)
                Positioned(
                  left: saLeft,
                  top: saTop,
                  width: saWidth,
                  height: saHeight,
                  child: IgnorePointer(
                    key: const ValueKey('hud-safe-area-border'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          // Dim cyan — visible over black without adding HUD glare.
                          color: const Color(0xFF00FFFF).withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
    );
  }
}

/// Slot layout — four named positions within the Safe Area.
///
/// BLINKER is now a full-Safe-Area layer at z-order bottom so [BlinkerWidget]
/// can place the left mark at the left edge and the right mark at the right
/// edge, including hazard (both sides simultaneously).  The other slots are
/// still labelled stubs pending their implementation Blocks.
class _HudSlots extends StatelessWidget {
  const _HudSlots({required this.saWidth, required this.saHeight});

  final double saWidth;
  final double saHeight;

  @override
  Widget build(BuildContext context) {
    // Proportional slot geometry inside the Safe Area.
    // Battery: right 12% wide, upper 60% tall.
    // Guidance: center 70% wide, upper 55% tall.
    // Minimap: left-aligned square, lower portion.
    final halfH = saHeight * 0.5;
    final upperH = saHeight * 0.6;
    final lowerY = saHeight * 0.55;
    final lowerH = saHeight - lowerY;
    final batteryW = saWidth * 0.12;
    final guidanceW = saWidth * 0.70;
    final guidanceX = (saWidth - guidanceW) / 2;
    final minimapSide = halfH.clamp(0.0, saWidth * 0.35);

    return Stack(
      children: <Widget>[
        // BLINKER — full Safe Area layer (lowest z-order).
        // BlinkerWidget positions marks at left/right edges via Positioned inside
        // its own Stack, so hazard shows both simultaneously.
        const Positioned.fill(
          child: BlinkerWidget(),
        ),

        // BATTERY — top-right corner
        Positioned(
          right: 0,
          top: 0,
          width: batteryW,
          height: upperH,
          child: const _SlotStub(label: 'BATTERY'),
        ),

        // GUIDANCE — centered horizontally, upper area
        Positioned(
          left: guidanceX,
          top: 0,
          width: guidanceW,
          height: upperH * 0.9,
          child: const _SlotStub(label: 'GUIDANCE'),
        ),

        // MINIMAP — lower-left, square
        Positioned(
          left: 0,
          top: lowerY,
          width: minimapSide,
          height: lowerH,
          child: const _SlotStub(label: 'MINIMAP'),
        ),
      ],
    );
  }
}

/// A labelled thin-outlined placeholder for a HUD slot.
///
/// Dim white outline + small label — clearly visible against black for layout
/// verification, but low-brightness so it does not burn-in the HUD projector
/// during development sessions.
class _SlotStub extends StatelessWidget {
  const _SlotStub({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.20),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.25),
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

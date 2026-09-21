import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/config_store.dart';
import '../services/minimap_viewport.dart';
import 'battery_geometry.dart';
import 'battery_widget.dart';
import 'blinker_widget.dart';
import 'speedcam_radar_widget.dart';
import '../providers/guidance.dart';

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
/// Slots: [BlinkerWidget] and [BatteryWidget] (real content). The MINIMAP
/// slot shows a schematic placeholder glyph (see `_MinimapGlyph`) — the real
/// Minimap is YNavi-drawn foreign content composited onto the HUD surface by
/// `MinimapHost`, not something HudRoot paints; the glyph is a debug aid so
/// the reserved area is visible during layout work, shown only when
/// [showSafeAreaBorder] is true so it never emits a ghost rectangle onto the
/// real windshield. Street + ETA come from **YNavi native** map-pixel chrome
/// (`NaviGuidanceLayer.setManeuverStreetInfoVisible`, 0055 redirect) — not a
/// Flutter plate. Trip [GuidanceEvent]s still relay for FL/diagnostics.
/// The BLINKER layer spans the full Safe Area so hazard can render both sides;
/// marks are positioned at the edges by [BlinkerWidget] via its own layout.
///
/// [showSafeAreaBorder] gates both the faint Safe Area outline AND the
/// MINIMAP slot glyph (debug aids; disabled in production, enabled in the DHU
/// preview).
class HudRoot extends ConsumerWidget {
  const HudRoot({
    super.key,
    this.showSafeAreaBorder = false,
    this.forceBlinkOn,
    this.forceDemoSpeedcam = false,
  });

  final bool showSafeAreaBorder;

  /// When non-null, forwarded to [BlinkerWidget.forceBlinkOn]. Used by the
  /// DHU Config Preview (`HudPreview` with `forceDemoSignals`) so demo hazard
  /// marks stay lit instead of extinguishing on the blink off-half — otherwise
  /// a glance or screenshot during the off-phase shows an empty preview even
  /// though `blinkerProvider` is correctly overridden to hazard.
  final bool? forceBlinkOn;

  /// When true, [SpeedcamRadarWidget] paints [SpeedcamRadarWidget.demoDanger]
  /// so Config Preview shows the CRT radar without FL inject.
  final bool forceDemoSpeedcam;

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
                  child: _HudSlots(
                    saWidth: saWidth,
                    saHeight: saHeight,
                    showStubs: showSafeAreaBorder,
                    forceBlinkOn: forceBlinkOn,
                    forceDemoSpeedcam: forceDemoSpeedcam,
                  ),
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

/// Slot layout — named positions within the Safe Area.
///
/// BLINKER is a full-Safe-Area layer at z-order bottom so [BlinkerWidget] can
/// place the left mark at the left edge and the right mark at the right edge,
/// including hazard (both sides simultaneously).  BATTERY is a real widget
/// ([BatteryWidget]: Steam-Deck battery + temp + charging stats).  MINIMAP is
/// a schematic placeholder glyph (`_MinimapGlyph`) at the real minimap
/// geometry ([minimapRectInSafeArea]) — the actual Minimap is YNavi-drawn
/// foreign content composited natively, not painted here; the glyph is a
/// debug-only stand-in, rendered only when [showStubs] is true so the
/// production HUD stays black except for real content.
class _HudSlots extends ConsumerWidget {
  const _HudSlots({
    required this.saWidth,
    required this.saHeight,
    required this.showStubs,
    this.forceBlinkOn,
    this.forceDemoSpeedcam = false,
  });

  final double saWidth;
  final double saHeight;
  final bool showStubs;
  final bool? forceBlinkOn;
  final bool forceDemoSpeedcam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pass resolvedSizeFraction, not just the preset, so the schematic glyph
    // tracks the Size slider in advanced mode too — otherwise the preview
    // silently disagrees with the rect actually handed to the native host.
    final minimapCfg = ref.watch(minimapConfigProvider);
    final minimapRect = minimapRectInSafeArea(
      preset: minimapCfg.preset,
      sizeFraction: minimapCfg.resolvedSizeFraction,
    );

    // Battery cluster placement — presets (left / right / rightTop) + fine
    // adjust. Default rightTop matches today's hard-coded top-right.
    final batteryCfg = ref.watch(batteryConfigProvider);
    // 0067: grow slot when charging stats are shown (3 lines vs 2).
    final chargingStatsVisible =
        ref.watch(chargingProvider) && batteryCfg.showChargingStats;
    final slotFracs = batteryClusterSlotFracs(
      chargingStatsVisible: chargingStatsVisible,
      sizeScale: batteryCfg.sizeScale,
    );
    final batteryRect = batteryClusterRect(
      saW: saWidth,
      saH: saHeight,
      placement: batteryCfg.placement,
      vertFrac: batteryCfg.vertFrac,
      sidePadFrac: batteryCfg.sidePadFrac,
      horizBiasFrac: batteryCfg.horizBiasFrac,
      widthFrac: slotFracs.widthFrac,
      heightFrac: slotFracs.heightFrac,
    );

    return Stack(
      children: <Widget>[
        // BLINKER — full Safe Area layer (lowest z-order).
        // BlinkerWidget positions marks at left/right edges via Positioned inside
        // its own Stack, so hazard shows both simultaneously.
        Positioned.fill(
          child: BlinkerWidget(forceBlinkOn: forceBlinkOn),
        ),

        // BATTERY — freely placeable cluster (icon + % + temp + charging kW).
        // Geometry from batteryClusterRect; default = prior top-right look.
        Positioned(
          key: const ValueKey('hud-battery-slot'),
          left: batteryRect.left,
          top: batteryRect.top,
          width: batteryRect.width,
          height: batteryRect.height,
          child: const BatteryWidget(),
        ),

        // SPEEDCAM RADAR — right mid (Alien/CRT), below battery; idle = empty.
        Positioned(
          right: saWidth * 0.02,
          top: saHeight * 0.28,
          width: saWidth * 0.22,
          height: saHeight * 0.55,
          child: SpeedcamRadarWidget(
            forceDemoDanger: forceDemoSpeedcam
                ? SpeedcamRadarWidget.demoDanger
                : null,
          ),
        ),

        // MINIMAP — real geometry via minimapRectInSafeArea (SQUARE_LEFT,
        // vertically centred, side = safeH × preset fraction) — same model
        // MinimapHost applies natively, so the debug glyph sits exactly where
        // the real Minimap would. F4: omit when minimap is disabled — the stub
        // must not pretend to be content while Minimap is off.
        // 0057: glyph follows surface gate (onlyWhileGuidance ∧ navActive).
        if (showStubs && ref.watch(minimapSurfaceActiveProvider))
          Positioned(
            key: const ValueKey('hud-minimap-glyph'),
            left: minimapRect.left * saWidth,
            top: minimapRect.top * saHeight,
            width: minimapRect.width * saWidth,
            height: minimapRect.height * saHeight,
            child: const _MinimapGlyph(),
          ),

      ],
    );
  }
}

/// A schematic minimap placeholder — a few bright green-yellow road strands
/// plus a heading marker on black, evoking the real YNavi-filtered map
/// without pretending to be it. Debug-only stand-in for the real Minimap,
/// which is foreign content YNavi draws into a surface `MinimapHost` composites
/// natively (never painted by Flutter) — see [_HudSlots] doc comment.
///
/// Deliberately does NOT try to simulate the native `ColorMatrix` HUD filter
/// or embed a captured map image: it would inevitably drift from
/// `createHudFilterPaint`, and colour fidelity is judged on the real HUD.
/// This glyph's job is layout and size, not visual fidelity.
class _MinimapGlyph extends StatelessWidget {
  const _MinimapGlyph();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).hudSlotMinimap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
        child: const CustomPaint(
          painter: _MinimapGlyphPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Paints the schematic minimap glyph: three road-like strands converging
/// toward the vehicle position, plus a small heading-up triangle marker.
/// Pure decoration — no data, no animation; a fixed evocative sketch.
class _MinimapGlyphPainter extends CustomPainter {
  const _MinimapGlyphPainter();

  // Emissive green-yellow — reads as a filtered nav map without claiming to
  // be the real (foreign, YNavi-drawn) content.
  static const Color _kRoad = Color(0xFFB6E24C);
  static const Color _kHeading = Color(0xFFEAF7C9);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final roadPaint = Paint()
      ..color = _kRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.045).clamp(1.0, 4.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strand1 = Path()
      ..moveTo(w * 0.10, h * 0.85)
      ..lineTo(w * 0.45, h * 0.55)
      ..lineTo(w * 0.40, h * 0.10);
    final strand2 = Path()
      ..moveTo(w * 0.90, h * 0.75)
      ..lineTo(w * 0.55, h * 0.55)
      ..lineTo(w * 0.65, h * 0.15);
    final strand3 = Path()
      ..moveTo(w * 0.15, h * 0.20)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.85, h * 0.35);

    canvas.drawPath(strand1, roadPaint);
    canvas.drawPath(strand2, roadPaint);
    canvas.drawPath(strand3, roadPaint);

    // Heading marker: small triangle at the vehicle position, pointing "up"
    // (direction of travel) — a typical heading-up nav marker.
    final headingPaint = Paint()
      ..color = _kHeading
      ..style = PaintingStyle.fill;
    final cx = w * 0.5;
    final cy = h * 0.52;
    final r = (w * 0.09).clamp(3.0, 14.0);
    final marker = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx - r * 0.7, cy + r * 0.7)
      ..lineTo(cx + r * 0.7, cy + r * 0.7)
      ..close();
    canvas.drawPath(marker, headingPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapGlyphPainter oldDelegate) => false;
}

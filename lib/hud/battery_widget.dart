import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/config_store.dart';
import 'battery_geometry.dart';

/// Emissive HUD battery indicator for the BATTERY slot.
///
/// Renders a battery pack (style-dependent) and/or a "NN%" text label per
/// [BatteryConfig.contentMode] / [BatteryConfig.style]. Temperature
/// [batteryTempCProvider] is shown when [BatteryConfig.showTemp] is set.
///
/// Pack styles ([BatteryStyle]) — driven by [BatteryLook] (0056 PDM):
///   outline   — squarish outline + continuous fill + nub (default)
///   filled    — 5 segment bars inside the pack ("Battery with bars")
///   pctInside — continuous fill with % text inside the pack (0062 dual-color)
///
/// Low-battery colour ramp (mirrors Steam Deck UX):
///   ≥ 30 %  → [_kFillGreen]   (emissive green)
///   15–29 % → [_kFillAmber]   (amber warning)
///   < 15 %  → [_kFillRed]     (red critical)
///
/// Charging panel: when [chargingProvider] is true AND
/// [BatteryConfig.showChargingStats], a secondary row shows the kW value
/// prominently.  Hidden when not charging (ADR 0003 show-while-charging rule
/// — this is app policy enforced here, not toggled by the user).
///
/// Emissive palette: bright marks on black.  No light backgrounds, cards, or
/// panels — only the marks themselves emit light.  Scaled by [BatteryConfig.sizeScale].
class BatteryWidget extends ConsumerWidget {
  const BatteryWidget({super.key});

  // ---------------------------------------------------------------------------
  // Emissive palette — all colours bright on black.
  // ---------------------------------------------------------------------------

  /// Healthy fill — emissive green, matches Steam Deck green-ish tint.
  static const Color _kFillGreen = Color(0xFF4ADE80);

  /// Warning fill — phase0 hud_amber #FFC107.
  static const Color _kFillAmber = Color(0xFFFFC107);

  /// Critical fill — emissive red.
  static const Color _kFillRed = Color(0xFFFF4444);

  /// Outline / body colour — dim white so the empty shell reads without glare.
  static const Color _kOutline = Color(0xFFCCCCCC);

  /// Primary text colour — near-white for high contrast on black.
  static const Color _kTextPrimary = Color(0xFFEEEEEE);

  /// Secondary text colour — dimmer for temperature and sub-labels.
  static const Color _kTextSecondary = Color(0xFF999999);

  /// kW accent — cyan / electric blue, distinct from the battery fill.
  static const Color _kKwColor = Color(0xFF67E8F9);

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(batteryConfigProvider);

    // showBattery=false → render absolutely nothing (0 pixels).
    if (!cfg.showBattery) return const SizedBox.shrink();

    final pct = ref.watch(batteryPctProvider); // int? 0-100
    final tempC = ref.watch(batteryTempCProvider); // double? °C
    final charging = ref.watch(chargingProvider);
    final kw = ref.watch(chargeKwProvider); // double?

    // F2: idle live HUD must stay black — do not paint empty chrome (`--%` /
    // `--°C`) when no battery/charge signal has arrived yet. Empty black is
    // fine; a hollow outline that looks broken is not.
    final isCharging = charging;
    if (pct == null && tempC == null && !isCharging) {
      return const SizedBox.shrink();
    }

    // Base unit: everything scales from this.
    // At sizeScale=1.0 the icon is 40×20 logical pixels — compact for the
    // top-right corner while legible on the 1024×576 HUD.
    final base = 20.0 * cfg.sizeScale;
    final bodyW = base * 2.0; // width of the battery body
    final bodyH = base; // height of the battery body
    final nubW = base * 0.15; // terminal nub width
    final nubH = base * 0.40; // terminal nub height

    // Fill level (0.0–1.0); null → show empty shell.
    final fillFrac = (pct != null) ? (pct.clamp(0, 100) / 100.0) : 0.0;

    // Fill colour based on charge level.
    final Color fillColor;
    if (pct == null || pct >= 30) {
      fillColor = _kFillGreen;
    } else if (pct >= 15) {
      fillColor = _kFillAmber;
    } else {
      fillColor = _kFillRed;
    }

    final showStats = isCharging && cfg.showChargingStats;
    final showIcon = cfg.contentMode != BatteryContentMode.textOnly;
    // Separate % below the pack: shown for both/textOnly, but suppressed when
    // pctInside paints the % inside the pack and the icon is visible (avoid
    // duplicating the label).
    final pctInsidePack =
        showIcon && cfg.style == BatteryStyle.pctInside;
    final showPctBelow = cfg.contentMode != BatteryContentMode.iconOnly &&
        !pctInsidePack;

    final labelStyle = TextStyle(
      color: _kTextPrimary,
      fontSize: base * 0.55,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    final tempStyle = TextStyle(
      color: _kTextSecondary,
      fontSize: base * 0.45,
      height: 1.0,
    );
    final pctLabel = pct != null ? '$pct%' : '--%';

    // Align the cluster toward the active edge so left placement mirrors
    // right without changing pack/styles (0051). Temp + charging stay in
    // this Column, so they move with the battery.
    final alignEnd = cfg.placement != BatteryPlacement.left;
    final clusterAlign =
        alignEnd ? Alignment.topRight : Alignment.topLeft;
    final clusterCross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      // Small inset from slot edges so marks breathe.
      padding: EdgeInsets.all(base * 0.3),
      // 0067b: no FittedBox(scaleDown) — it reversed sizeScale past ~1.5×
      // once content exceeded the slot. Slot grows with sizeScale in
      // batteryClusterSlotFracs; Align keeps marks at their true size.
      child: ClipRect(
        child: Align(
        alignment: clusterAlign,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: clusterCross,
          children: <Widget>[
            // ---- Battery icon (pack) ----
            if (showIcon)
              SizedBox(
                key: const ValueKey('battery-icon'),
                width: bodyW + nubW,
                height: bodyH,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    CustomPaint(
                      size: Size(bodyW + nubW, bodyH),
                      painter: _BatteryPainter(
                        fillFrac: fillFrac,
                        fillColor: fillColor,
                        outlineColor: _kOutline,
                        bodyW: bodyW,
                        bodyH: bodyH,
                        nubW: nubW,
                        nubH: nubH,
                        style: cfg.style,
                        // Charging bolt is gated on raw isCharging state alone,
                        // not on showChargingStats: the bolt communicates
                        // *that* the car is charging; the stats panel below is
                        // supplementary detail the user may suppress.
                        showBolt: isCharging,
                      ),
                    ),
                    if (pctInsidePack)
                      Positioned(
                        left: 0,
                        width: bodyW,
                        top: 0,
                        bottom: 0,
                        child: _DualColorPctLabel(
                          key: const ValueKey('battery-inline-pct'),
                          label: pctLabel,
                          bodyW: bodyW,
                          bodyH: bodyH,
                          fillFrac: fillFrac,
                          filledColor: const Color(0xFF000000),
                          emptyColor: _kTextPrimary,
                        ),
                      ),
                  ],
                ),
              ),

            // ---- Percentage text (below pack, when not painted inside) ----
            if (showPctBelow) ...<Widget>[
              if (showIcon) SizedBox(height: base * 0.12),
              Text(
                pctLabel,
                key: const ValueKey('battery-pct-text'),
                style: labelStyle,
              ),
            ],

            // ---- Temperature row (optional) ----
            if (cfg.showTemp) ...<Widget>[
              SizedBox(height: base * 0.18),
              Text(
                tempC != null ? '${tempC.toStringAsFixed(0)}°C' : '--°C',
                key: const ValueKey('battery-temp-text'),
                style: tempStyle,
              ),
            ],

            // ---- Charging stats panel (show-while-charging) ----
            if (showStats) ...<Widget>[
              SizedBox(height: base * 0.30),
              _ChargingStats(
                key: const ValueKey('charging-stats'),
                kw: kw,
                base: base,
                kwColor: _kKwColor,
                secondaryColor: _kTextSecondary,
                crossAxisAlignment: clusterCross,
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Battery icon painter — style-dependent pack look.
// ---------------------------------------------------------------------------

/// Paints the battery body per [BatteryStyle]:
/// - [BatteryStyle.outline]/[BatteryStyle.pctInside]: squarish outline
///   + continuous fill + nub + bolt
/// - [BatteryStyle.filled]: outline + 5 segment bars + nub + bolt
class _BatteryPainter extends CustomPainter {
  const _BatteryPainter({
    required this.fillFrac,
    required this.fillColor,
    required this.outlineColor,
    required this.bodyW,
    required this.bodyH,
    required this.nubW,
    required this.nubH,
    required this.style,
    this.showBolt = false,
  });

  final double fillFrac;
  final Color fillColor;
  final Color outlineColor;
  final double bodyW;
  final double bodyH;
  final double nubW;
  final double nubH;
  final BatteryStyle style;
  final bool showBolt;

  static const int _kSegmentCount = 5;

  @override
  void paint(Canvas canvas, Size size) {
    // 0056 PDM squarish corners; 0063 thinner outline (stroke toned down).
    // Stroke/pad shared with batteryPackFillEdgeX so 0062 % clip matches fill.
    final strokeW = batteryPackStrokeW(bodyH);
    final radius = bodyH * 0.08;

    // ---- Body outline ----
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyW, bodyH),
      Radius.circular(radius),
    );
    canvas.drawRRect(bodyRect, outlinePaint);

    // ---- Terminal nub (right side) ----
    final nubPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.fill;
    final nubTop = (bodyH - nubH) / 2;
    final nubRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyW, nubTop, nubW, nubH),
      Radius.circular(radius * 0.5),
    );
    canvas.drawRRect(nubRect, nubPaint);

    final innerPad = batteryPackInnerPad(bodyH);
    final innerW = bodyW - innerPad * 2;
    final innerH = bodyH - innerPad * 2;

    if (style == BatteryStyle.filled) {
      // ---- Segmented bars ----
      if (innerW > 0 && innerH > 0) {
        final gap = innerW * 0.06;
        final segW =
            (innerW - gap * (_kSegmentCount - 1)) / _kSegmentCount;
        final lit = (fillFrac * _kSegmentCount).ceil().clamp(0, _kSegmentCount);
        final fillPaint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
        final emptyPaint = Paint()
          ..color = outlineColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        final segRadius = Radius.circular(radius * 0.35);
        canvas.save();
        canvas.clipRRect(bodyRect.deflate(strokeW / 2));
        for (var i = 0; i < _kSegmentCount; i++) {
          final x = innerPad + i * (segW + gap);
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, innerPad, segW, innerH),
            segRadius,
          );
          canvas.drawRRect(rect, i < lit ? fillPaint : emptyPaint);
        }
        canvas.restore();
      }
    } else {
      // ---- Continuous fill (outline + pctInside) ----
      if (fillFrac > 0 && innerW > 0 && innerH > 0) {
        final fillW = innerW * fillFrac;
        if (fillW > 0) {
          final fillRadius = Radius.circular(radius * 0.5);
          final fillPaint = Paint()
            ..color = fillColor
            ..style = PaintingStyle.fill;
          final fillRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(innerPad, innerPad, fillW, innerH),
            fillRadius,
          );
          canvas.save();
          canvas.clipRRect(bodyRect.deflate(strokeW / 2));
          canvas.drawRRect(fillRect, fillPaint);
          canvas.restore();
        }
      }
    }

    // ---- Lightning bolt (charging indicator inside icon) ----
    if (showBolt) {
      final boltPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.fill;

      // Simple ⚡ path scaled to bodyH.
      final cx = bodyW / 2;
      final h = bodyH;
      final bolt = Path()
        ..moveTo(cx + h * 0.05, h * 0.10)
        ..lineTo(cx - h * 0.12, h * 0.52)
        ..lineTo(cx + h * 0.04, h * 0.52)
        ..lineTo(cx - h * 0.05, h * 0.90)
        ..lineTo(cx + h * 0.12, h * 0.48)
        ..lineTo(cx - h * 0.04, h * 0.48)
        ..close();
      canvas.drawPath(bolt, boltPaint);
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) =>
      old.fillFrac != fillFrac ||
      old.fillColor != fillColor ||
      old.showBolt != showBolt ||
      old.outlineColor != outlineColor ||
      old.style != style;
}

// ---------------------------------------------------------------------------
// Dual-color % inside pack (0062) — black on fill, white on empty, clipped.
// ---------------------------------------------------------------------------

/// Percentage label painted twice and clipped at the pack fill boundary so
/// the glyphs read black over the filled portion and white over the empty.
class _DualColorPctLabel extends StatelessWidget {
  const _DualColorPctLabel({
    super.key,
    required this.label,
    required this.bodyW,
    required this.bodyH,
    required this.fillFrac,
    required this.filledColor,
    required this.emptyColor,
  });

  final String label;
  final double bodyW;
  final double bodyH;
  final double fillFrac;
  final Color filledColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    // 0063: % fills the inner fill height (taller glyph inside the pack).
    final style = TextStyle(
      fontSize: batteryPackInnerH(bodyH),
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final fillEdge = batteryPackFillEdgeX(
      bodyW: bodyW,
      bodyH: bodyH,
      fillFrac: fillFrac,
    );
    // StackFit.expand: clip X is in pack-body coords (same as fillEdge).
    // Without expand, ClipRect sizes to the Text and fillEdge (pack space)
    // often covers the whole glyph — white on empty never shows (0062 FAIL).
    Widget pct(Color color) => Center(
          child: Text(
            label,
            style: style.copyWith(color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
          ),
        );
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: <Widget>[
        // Empty portion (right of fill) — white, clipped to empty side.
        ClipRect(
          clipper: _RightOfEdgeClipper(fillEdge),
          child: pct(emptyColor),
        ),
        // Filled portion (left of fill edge) — black, clipped at boundary.
        ClipRect(
          clipper: _LeftEdgeClipper(fillEdge),
          child: pct(filledColor),
        ),
      ],
    );
  }
}

/// Clips to [0, edgeX] × full height — filled / left side of dual-color %.
class _LeftEdgeClipper extends CustomClipper<Rect> {
  const _LeftEdgeClipper(this.edgeX);

  final double edgeX;

  @override
  Rect getClip(Size size) {
    final w = edgeX.clamp(0.0, size.width);
    return Rect.fromLTWH(0, 0, w, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftEdgeClipper old) => old.edgeX != edgeX;
}

/// Clips to [edgeX, width] × full height — empty / right side of dual-color %.
class _RightOfEdgeClipper extends CustomClipper<Rect> {
  const _RightOfEdgeClipper(this.edgeX);

  final double edgeX;

  @override
  Rect getClip(Size size) {
    final x = edgeX.clamp(0.0, size.width);
    return Rect.fromLTWH(x, 0, size.width - x, size.height);
  }

  @override
  bool shouldReclip(covariant _RightOfEdgeClipper old) => old.edgeX != edgeX;
}

// ---------------------------------------------------------------------------
// Charging stats panel (show-while-charging).
// ---------------------------------------------------------------------------

/// Shows charging power (kW prominent) when the car is charging.
///
/// Visibility is governed by [BatteryWidget]: this widget is only inserted
/// into the tree when charging == true && showChargingStats == true, so
/// it never renders while not charging (ADR 0003).
class _ChargingStats extends StatelessWidget {
  const _ChargingStats({
    super.key,
    required this.kw,
    required this.base,
    required this.kwColor,
    required this.secondaryColor,
    this.crossAxisAlignment = CrossAxisAlignment.end,
  });

  final double? kw;
  final double base;
  final Color kwColor;
  final Color secondaryColor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    // kW label — large and prominent (primary charging info on the HUD).
    final kwText = kw != null ? '${kw!.toStringAsFixed(0)} kW' : '-- kW';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        Text(
          kwText,
          key: const ValueKey('charging-kw-text'),
          style: TextStyle(
            color: kwColor,
            fontSize: base * 0.70,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

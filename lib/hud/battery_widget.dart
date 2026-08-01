import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/config_store.dart';

/// Emissive HUD battery indicator (Steam-Deck-style) for the BATTERY slot.
///
/// Renders a rounded-rectangle battery body + right-side terminal nub, an
/// inner fill bar proportional to [batteryPctProvider], and a "NN%" text
/// label stacked *below* the icon (not beside it — see the layout note on the
/// `FittedBox` below for why). Temperature [batteryTempCProvider] is shown
/// when [BatteryConfig.showTemp] is set.
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

    final pct = ref.watch(batteryPctProvider);       // int? 0-100
    final tempC = ref.watch(batteryTempCProvider);   // double? °C
    final charging = ref.watch(chargingProvider);    // bool?
    final kw = ref.watch(chargeKwProvider);          // double?

    // Base unit: everything scales from this.
    // At sizeScale=1.0 the icon is 40×20 logical pixels — compact for the
    // top-right corner while legible on the 1024×576 HUD.
    final base = 20.0 * cfg.sizeScale;
    final bodyW = base * 2.0;   // width of the battery body
    final bodyH = base;          // height of the battery body
    final nubW = base * 0.15;   // terminal nub width
    final nubH = base * 0.40;   // terminal nub height

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

    final isCharging = charging == true;
    final showStats = isCharging && cfg.showChargingStats;

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

    return Padding(
      // Small inset from slot edges so marks breathe.
      padding: EdgeInsets.all(base * 0.3),
      // FittedBox around the WHOLE panel (icon, pct, temp, charging-stats) —
      // kept as a safety net, not removed (Block 0026 fixed a real overflow
      // this way: temp/charging-stats rows were unwrapped and a Column of
      // all three could overflow the fixed BATTERY slot under tight
      // constraints — see that Block's Reconciliation item 4). Once the
      // panel's natural size exceeds the slot, FittedBox scales the whole
      // thing down uniformly rather than crashing — that part of the
      // contract must not regress (pinned in
      // test/widgets/battery_widget_test.dart, "no overflow at max
      // sizeScale with everything shown").
      //
      // What changed here: the layout *feeding* this FittedBox, to make the
      // `sizeScale` slider (0.5–2.5) actually honest. Previously icon+pct sat
      // in a Row beside each other; that row's natural width already
      // exceeded the slot (~98 logical px at the reference Safe Area — ~12%
      // of its width, see hud_root.dart) by sizeScale≈1.07, so FittedBox was
      // scaling everything back down for roughly the top 75% of the slider's
      // labelled range — moving the slider past its first quarter did almost
      // nothing visible. The BATTERY slot is tall and narrow (~12% Safe Area
      // width, ~60% of its height), so a side-by-side icon+text row is the
      // wrong shape for it. Stacking icon → pct → temp → charging-stats
      // vertically instead moves the binding constraint to whichever single
      // line is widest (never the sum of two side-by-side elements), which
      // roughly triples the genuinely-growing portion of the range: real
      // growth up to sizeScale≈1.4 with temp+charging-stats both showing (the
      // worst case, gated by the "NN kW" line), and out to sizeScale≈2.2 when
      // charging stats aren't showing (gated by the "NN%" line instead) — see
      // the measured breakpoints in test/widgets/battery_widget_test.dart.
      //
      // This still doesn't make the *entire* labelled 0.5–2.5 range honest in
      // the worst case (temp + charging stats both on) — the slot is a hard
      // physical constraint (see hud_root.dart:148-154) and no layout of this
      // content fits an unbounded size into a fixed box. Narrowing the
      // slider's own max to better match (e.g. ~1.5) would need a change in
      // lib/screens/hud_settings_screen.dart, out of this Block's scope.
      child: FittedBox(
        alignment: Alignment.topRight,
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // ---- Battery icon ----
            // The battery body + fill painted via CustomPaint.
            CustomPaint(
              key: const ValueKey('battery-icon'),
              size: Size(bodyW + nubW, bodyH),
              painter: _BatteryPainter(
                fillFrac: fillFrac,
                fillColor: fillColor,
                outlineColor: _kOutline,
                bodyW: bodyW,
                bodyH: bodyH,
                nubW: nubW,
                nubH: nubH,
                // Charging bolt is gated on raw isCharging state alone, not
                // on showChargingStats: the bolt communicates *that* the car
                // is charging (state, always relevant), while the stats
                // panel below is supplementary *detail* (kW) the user may
                // choose to suppress independently. Turning the panel off
                // should not also hide the fact that the car is plugged in.
                showBolt: isCharging,
              ),
            ),

            // ---- Percentage text ----
            SizedBox(height: base * 0.12),
            Text(
              pct != null ? '$pct%' : '--%',
              key: const ValueKey('battery-pct-text'),
              style: labelStyle,
            ),

            // ---- Temperature row (optional) ----
            if (cfg.showTemp) ...<Widget>[
              SizedBox(height: base * 0.18),
              Text(
                tempC != null
                    ? '${tempC.toStringAsFixed(0)}°C'
                    : '--°C',
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Battery icon painter — Steam-Deck-style.
// ---------------------------------------------------------------------------

/// Paints the battery body: rounded rectangle outline + proportional fill bar
/// + terminal nub on the right + optional lightning bolt while charging.
///
/// Design mirrors the Steam Deck battery icon: clean rounded rectangle, filled
/// from the left, thin nub on the right (positive terminal).  No segments —
/// smooth gradient fill reads better at small HUD sizes.
class _BatteryPainter extends CustomPainter {
  const _BatteryPainter({
    required this.fillFrac,
    required this.fillColor,
    required this.outlineColor,
    required this.bodyW,
    required this.bodyH,
    required this.nubW,
    required this.nubH,
    this.showBolt = false,
  });

  final double fillFrac;
  final Color fillColor;
  final Color outlineColor;
  final double bodyW;
  final double bodyH;
  final double nubW;
  final double nubH;
  final bool showBolt;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = bodyH * 0.07;
    final radius = bodyH * 0.22;

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

    // ---- Fill bar ----
    if (fillFrac > 0) {
      final innerPad = strokeW + bodyH * 0.08;
      final innerW = bodyW - innerPad * 2;
      final innerH = bodyH - innerPad * 2;
      final fillW = innerW * fillFrac;

      if (fillW > 0 && innerH > 0) {
        final fillRadius = Radius.circular(radius * 0.5);
        final fillPaint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(innerPad, innerPad, fillW, innerH),
          fillRadius,
        );
        canvas.clipRRect(bodyRect.deflate(strokeW / 2));
        canvas.drawRRect(fillRect, fillPaint);
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
      old.outlineColor != outlineColor;
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
  });

  final double? kw;
  final double base;
  final Color kwColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    // kW label — large and prominent (primary charging info on the HUD).
    final kwText = kw != null ? '${kw!.toStringAsFixed(0)} kW' : '-- kW';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
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

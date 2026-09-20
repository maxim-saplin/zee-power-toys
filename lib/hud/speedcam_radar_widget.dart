import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/speedcam.dart';
import '../services/config_store.dart';
import '../services/speedcam.dart';

enum SpeedcamRadarVariant { hudCompact, dhuLarge }

class SpeedcamRadarBlip {
  const SpeedcamRadarBlip({
    required this.bearingDeg,
    required this.distanceM,
    this.highlight = false,
    this.maxspeed,
  });

  final double bearingDeg;
  final double distanceM;
  final bool highlight;
  final int? maxspeed;
}

/// HUD / DHU speedcam radar — Default (text) or Alien (CRT wedge).
class SpeedcamRadarWidget extends HookConsumerWidget {
  const SpeedcamRadarWidget({
    super.key,
    this.forceDemoDanger,
    this.variant = SpeedcamRadarVariant.hudCompact,
    this.displayRadiusM,
    this.alwaysShow = false,
  });

  final SpeedcamDanger? forceDemoDanger;
  final SpeedcamRadarVariant variant;

  /// Outer ring metres (DHU zoom-out). Defaults: HUD 500, DHU from config.
  final double? displayRadiusM;

  /// When true (DHU), paint even with no danger / no pose.
  final bool alwaysShow;

  static const Color phosphor = Color(0xFF39FF14);
  static const Color phosphorDim = Color(0xFF1A7A0A);
  static const Color phosphorGlow = Color(0xFF00FF66);

  static final demoDanger = SpeedcamDanger(
    cam: const SpeedcamPoint(
      id: 'demo-cam',
      lat: 53.9,
      lon: 27.56,
      maxspeed: 60,
    ),
    distanceM: 200,
    bearingDeg: 45,
    insideApproach: true,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(speedcamConfigProvider);
    if (variant == SpeedcamRadarVariant.hudCompact && !cfg.hudRadarEnabled) {
      return const SizedBox.shrink();
    }

    final snap = ref.watch(speedcamSnapshotProvider);
    final liveDanger = ref.watch(speedcamDangerProvider);
    final danger = forceDemoDanger ?? liveDanger;
    final look = cfg.radarLook;

    final approachM = snap.approachRadiusM > 0
        ? snap.approachRadiusM
        : cfg.dhuRangeM;
    final range = displayRadiusM ??
        (variant == SpeedcamRadarVariant.dhuLarge ? cfg.dhuRangeM : approachM);

    final blips = <SpeedcamRadarBlip>[];
    if (forceDemoDanger != null) {
      // On-route contact bright; a couple of in-range cams dim (preview parity).
      blips.add(SpeedcamRadarBlip(
        bearingDeg: forceDemoDanger!.bearingDeg,
        distanceM: forceDemoDanger!.distanceM,
        highlight: true,
        maxspeed: forceDemoDanger!.cam.maxspeed,
      ));
      blips.add(const SpeedcamRadarBlip(
        bearingDeg: -35,
        distanceM: 380,
        highlight: false,
        maxspeed: 70,
      ));
      blips.add(const SpeedcamRadarBlip(
        bearingDeg: 55,
        distanceM: 520,
        highlight: false,
        maxspeed: 50,
      ));
    } else if (snap.host != null) {
      final heading = snap.host!.headingDeg;
      for (final cam in snap.cams) {
        final d = haversineMetres(
          snap.host!.lat,
          snap.host!.lon,
          cam.lat,
          cam.lon,
        );
        if (d > range) continue;
        final isDanger = danger != null && danger.cam.id == cam.id;
        final absBearing = initialBearingDegrees(
          snap.host!.lat,
          snap.host!.lon,
          cam.lat,
          cam.lon,
        );
        blips.add(SpeedcamRadarBlip(
          // Alien fan + Default arrow expect forward-relative degrees.
          bearingDeg: relativeBearingDegrees(absBearing, heading),
          distanceM: d,
          highlight: isDanger,
          maxspeed: cam.maxspeed,
        ));
      }
      if (danger != null &&
          danger.insideApproach &&
          !blips.any((b) => b.highlight)) {
        blips.add(SpeedcamRadarBlip(
          bearingDeg: relativeBearingDegrees(danger.bearingDeg, heading),
          distanceM: danger.distanceM,
          highlight: true,
          maxspeed: danger.cam.maxspeed,
        ));
      }
    } else if (danger != null && danger.insideApproach) {
      // No host pose — danger.bearingDeg may be absolute; treat as relative
      // (fail-open) so the approach blip still paints near center.
      blips.add(SpeedcamRadarBlip(
        bearingDeg: relativeBearingDegrees(danger.bearingDeg, null),
        distanceM: danger.distanceM,
        highlight: true,
        maxspeed: danger.cam.maxspeed,
      ));
    }

    final approaching = danger != null && danger.insideApproach;
    final hasHighlight = blips.any((b) => b.highlight);

    // Default: show ONLY when approaching (HUD-right text). Nothing otherwise.
    // Alien: show CRT when approaching, alwaysShow (DHU), or force demo.
    // HUD Alien with radar ON but idle: still nothing (Maxim: no cam → nothing).
    final showDefault = look == SpeedcamRadarLook.defaultLook &&
        (approaching || forceDemoDanger != null || alwaysShow);
    final showAlien = look == SpeedcamRadarLook.alien &&
        (alwaysShow ||
            hasHighlight ||
            approaching ||
            forceDemoDanger != null);

    if (look == SpeedcamRadarLook.defaultLook && !showDefault) {
      return const SizedBox.shrink();
    }
    if (look == SpeedcamRadarLook.alien && !showAlien) {
      return const SizedBox.shrink();
    }

    SpeedcamRadarBlip? highlight;
    for (final b in blips) {
      if (b.highlight) {
        highlight = b;
        break;
      }
    }
    final labelDist = highlight?.distanceM ?? danger?.distanceM;
    final labelBearing = highlight?.bearingDeg ?? danger?.bearingDeg;
    final labelMax = highlight?.maxspeed ?? danger?.cam.maxspeed;

    final keyName = variant == SpeedcamRadarVariant.dhuLarge
        ? 'dhu-speedcam-radar'
        : 'hud-speedcam-radar';
    final lookKey = look == SpeedcamRadarLook.alien
        ? 'speedcam-look-alien'
        : 'speedcam-look-default';

    if (look == SpeedcamRadarLook.defaultLook) {
      return Semantics(
        key: ValueKey(keyName),
        label: labelDist != null
            ? 'Speedcam ${labelDist.round()} metres'
            : 'Speedcam',
        child: _DefaultSpeedcamReadout(
          key: ValueKey(lookKey),
          distanceM: labelDist,
          bearingDeg: labelBearing,
          maxspeed: labelMax,
          compact: variant == SpeedcamRadarVariant.hudCompact,
        ),
      );
    }

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 2200),
    );
    useEffect(() {
      controller.repeat();
      return null;
    }, const []);

    return Semantics(
      key: ValueKey(keyName),
      label: labelDist != null
          ? 'Speedcam radar ${labelDist.round()} metres'
          : 'Speedcam radar',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            key: ValueKey(lookKey),
            painter: _AlienWedgePainter(
              sweepT: controller.value,
              blinkT: controller.value,
              blips: blips,
              displayRadiusM: range,
              approachRadiusM: approachM,
              readoutM: labelDist,
              maxspeed: labelMax,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Clean HUD-right: bearing arrow + distance (no CRT).
class _DefaultSpeedcamReadout extends StatelessWidget {
  const _DefaultSpeedcamReadout({
    super.key,
    required this.distanceM,
    required this.bearingDeg,
    required this.maxspeed,
    required this.compact,
  });

  final double? distanceM;
  final double? bearingDeg;
  final int? maxspeed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dist = distanceM;
    final bearing = bearingDeg;
    final arrow = _bearingArrow(bearing);
    final distLabel = dist == null ? '—' : '${dist.round()} m';
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: compact ? 18 : 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      shadows: const [
        Shadow(blurRadius: 4, color: Colors.black87),
      ],
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: compact ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              arrow,
              key: const ValueKey('speedcam-default-bearing'),
              style: style.copyWith(fontSize: compact ? 22 : 36),
            ),
            Text(
              distLabel,
              key: const ValueKey('speedcam-default-distance'),
              style: style,
            ),
            if (maxspeed != null)
              Text(
                '$maxspeed',
                key: const ValueKey('speedcam-default-maxspeed'),
                style: style.copyWith(
                  fontSize: compact ? 14 : 20,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _bearingArrow(double? bearingDeg) {
    if (bearingDeg == null) return '·';
    // Map bearing relative to host forward (0 = ahead) into 8-way arrow.
    var b = bearingDeg % 360;
    if (b < 0) b += 360;
    // Bearing is forward-relative (0058); 0 = ahead on screen.
    if (b >= 337.5 || b < 22.5) return '↑';
    if (b < 67.5) return '↗';
    if (b < 112.5) return '→';
    if (b < 157.5) return '↘';
    if (b < 202.5) return '↓';
    if (b < 247.5) return '↙';
    if (b < 292.5) return '←';
    return '↖';
  }
}

/// Closer blips are larger (0042).
double alienBlipRadiusForDistanceM(
  double distanceM, {
  required double displayRadiusM,
  bool highlight = false,
}) {
  final frac = (distanceM / displayRadiusM).clamp(0.0, 1.0);
  final base = 7.0 - frac * 4.5;
  return highlight ? base + 1.2 : base;
}

/// Closer blips are brighter (0042).
double alienBlipAlphaForDistanceM(
  double distanceM, {
  required double displayRadiusM,
}) {
  final frac = (distanceM / displayRadiusM).clamp(0.0, 1.0);
  return (0.95 - frac * 0.55).clamp(0.35, 0.95);
}

/// Alien motion-tracker: prop fan + expanding range rings from center + grit.
class _AlienWedgePainter extends CustomPainter {
  _AlienWedgePainter({
    required this.sweepT,
    required this.blinkT,
    required this.blips,
    required this.displayRadiusM,
    required this.approachRadiusM,
    required this.readoutM,
    required this.maxspeed,
  });

  final double sweepT;
  final double blinkT;
  final List<SpeedcamRadarBlip> blips;
  final double displayRadiusM;
  final double approachRadiusM;
  final double? readoutM;
  final int? maxspeed;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // Curved CRT face (older tube — rounded square, not sharp rect).
    final crtRRect = RRect.fromRectAndRadius(
      bounds.deflate(1.5),
      Radius.circular(math.min(size.width, size.height) * 0.12),
    );
    final c = Offset(size.width / 2, size.height * 0.88);
    final r = math.min(size.width, size.height) * 0.78;

    // Bezel / outside CRT
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF0A0A0A));

    // Clip all phosphor to curved CRT glass (hard clip via saveLayer).
    canvas.saveLayer(bounds, Paint());
    canvas.clipRRect(crtRRect, doAntiAlias: true);

    // Deep CRT black-green ground
    canvas.drawRRect(crtRRect, Paint()..color = const Color(0xFF010401));

    // Heavy phosphor grain (inside glass only)
    final grit = Paint()..color = const Color(0x2200FF44);
    for (var i = 0; i < 140; i++) {
      final x = ((i * 131) % 997) / 997.0 * size.width;
      final y = ((i * 89) % 991) / 991.0 * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, 1.1, 1.1), grit);
    }

    // Dense horizontal scanlines with slight barrel bow near edges
    final scan = Paint()..color = const Color(0x3300FF55);
    for (var y = 0.0; y < size.height; y += 2.0) {
      final ny = (y / size.height) * 2 - 1;
      final bow = 3.5 * ny * ny; // edge distortion
      canvas.drawLine(Offset(bow, y), Offset(size.width - bow, y), scan);
    }

    // Prop tracker: wide front fan (~100°) from bottom origin
    const wedgeHalf = 50 * math.pi / 180;
    final baseAngle = -math.pi / 2;

    final wedgePath = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        baseAngle - wedgeHalf,
        wedgeHalf * 2,
        false,
      )
      ..close();

    // Dim fill inside fan
    canvas.drawPath(
      wedgePath,
      Paint()
        ..color = const Color(0xFF0A3D0A).withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // Outer fan outline
    canvas.drawPath(
      wedgePath,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Radial dividers
    for (var i = -2; i <= 2; i++) {
      if (i == 0) continue;
      final a = baseAngle + i * (wedgeHalf / 2);
      canvas.drawLine(
        c,
        Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
        Paint()
          ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.4)
          ..strokeWidth = 1.1,
      );
    }
    canvas.drawLine(
      c,
      Offset(c.dx + r * math.cos(baseAngle), c.dy + r * math.sin(baseAngle)),
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.55)
        ..strokeWidth = 1.4,
    );

    // Static range arcs (dashed) — already angularly limited to fan
    for (final frac in [0.28, 0.55, 0.82, 1.0]) {
      final rr = r * frac;
      final paint = Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(
          alpha: frac == 1.0 ? 0.8 : 0.42,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = frac == 1.0 ? 2.0 : 1.15;
      const steps = 32;
      for (var s = 0; s < steps; s++) {
        if (s.isOdd) continue;
        final a0 = baseAngle - wedgeHalf + (2 * wedgeHalf) * (s / steps);
        final a1 = baseAngle - wedgeHalf + (2 * wedgeHalf) * ((s + 1) / steps);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: rr),
          a0,
          a1 - a0,
          false,
          paint,
        );
      }
    }

    // Expanding rings — hard-clipped to fan (no bloom bleed outside).
    canvas.saveLayer(bounds, Paint());
    canvas.clipPath(wedgePath, doAntiAlias: true);
    // Single expanding wave — slightly bolder (Maxim).
    final phase = sweepT % 1.0;
    final rr = r * phase;
    if (rr >= 4 && rr <= r) {
      final fade = (1.0 - phase);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr),
        baseAngle - wedgeHalf,
        wedgeHalf * 2,
        false,
        Paint()
          ..color = SpeedcamRadarWidget.phosphorGlow.withValues(
            alpha: 0.25 + 0.6 * fade,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 + 1.4 * fade,
      );
    }
    canvas.restore(); // end wedge clip layer

    // CRT edge vignette / corner distortion
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          const Color(0x00000000),
          const Color(0x99000000),
        ],
        stops: const [0.55, 1.0],
      ).createShader(bounds);
    canvas.drawRRect(crtRRect, vignette);

    // Glass rim highlight
    canvas.drawRRect(
      crtRRect,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Origin pip (host)
    canvas.drawCircle(
      c,
      4,
      Paint()..color = SpeedcamRadarWidget.phosphorGlow,
    );
    canvas.drawCircle(
      c,
      2,
      Paint()..color = const Color(0xFFE8FFE8),
    );

    // Blips — round dots (Maxim: not squares). Bearings are forward-relative
    // (0058). On-route highlight clamps to fan edge so it never vanishes.
    for (final b in blips) {
      var rel = _normalizeBearing(b.bearingDeg) * math.pi / 180;
      if (rel.abs() > wedgeHalf) {
        if (!b.highlight) continue;
        rel = rel.isNegative ? -wedgeHalf : wedgeHalf;
      }
      final a = baseAngle + rel;
      final frac = (b.distanceM / displayRadiusM).clamp(0.0, 1.0);
      final p = Offset(
        c.dx + r * frac * math.cos(a),
        c.dy + r * frac * math.sin(a),
      );
      final rad = alienBlipRadiusForDistanceM(
        b.distanceM,
        displayRadiusM: displayRadiusM,
        highlight: b.highlight,
      );
      // Route / on-course = bright; other in-range cams = dim.
      final baseA = b.highlight
          ? alienBlipAlphaForDistanceM(
              b.distanceM,
              displayRadiusM: displayRadiusM,
            )
          : (alienBlipAlphaForDistanceM(
                    b.distanceM,
                    displayRadiusM: displayRadiusM,
                  ) *
                  0.35)
              .clamp(0.18, 0.45);
      // Slight blink on all dots.
      final blink = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(blinkT * math.pi * 2 * 2));
      final alpha = (baseA * blink).clamp(0.12, 1.0);
      final glowA = b.highlight ? alpha * 0.4 : alpha * 0.2;
      canvas.drawCircle(
        p,
        rad + (b.highlight ? 2.4 : 1.4),
        Paint()
          ..color = SpeedcamRadarWidget.phosphorGlow.withValues(alpha: glowA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        p,
        b.highlight ? rad : rad * 0.85,
        Paint()
          ..color = (b.highlight
                  ? SpeedcamRadarWidget.phosphorGlow
                  : SpeedcamRadarWidget.phosphor)
              .withValues(alpha: alpha),
      );
    }

    if (readoutM != null) {
      // Large distance in km; smaller camera speed limit below (Maxim).
      final km = TextPainter(
        text: TextSpan(
          text: (readoutM! / 1000).toStringAsFixed(2),
          style: const TextStyle(
            color: SpeedcamRadarWidget.phosphor,
            fontSize: 22,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final limit = TextPainter(
        text: TextSpan(
          text: maxspeed != null ? '$maxspeed' : '',
          style: TextStyle(
            color: SpeedcamRadarWidget.phosphor.withValues(alpha: 0.75),
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bottom = size.height - 8;
      km.paint(canvas, Offset(8, bottom - km.height - (limit.height > 0 ? limit.height + 2 : 0)));
      if (maxspeed != null) {
        limit.paint(canvas, Offset(8, bottom - limit.height));
      }
    }

    canvas.restore(); // end CRT glass

  }

  double _normalizeBearing(double bearingDeg) {
    var b = bearingDeg % 360;
    if (b > 180) b -= 360;
    if (b < -180) b += 360;
    return b;
  }

  @override
  bool shouldRepaint(covariant _AlienWedgePainter old) =>
      old.sweepT != sweepT ||
      old.blinkT != blinkT ||
      old.blips != blips ||
      old.displayRadiusM != displayRadiusM ||
      old.readoutM != readoutM ||
      old.maxspeed != maxspeed;
}

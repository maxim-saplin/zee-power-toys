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

    final range = displayRadiusM ??
        (variant == SpeedcamRadarVariant.dhuLarge ? cfg.dhuRangeM : 500.0);

    final blips = <SpeedcamRadarBlip>[];
    if (forceDemoDanger != null) {
      blips.add(SpeedcamRadarBlip(
        bearingDeg: forceDemoDanger!.bearingDeg,
        distanceM: forceDemoDanger!.distanceM,
        highlight: true,
        maxspeed: forceDemoDanger!.cam.maxspeed,
      ));
    } else if (snap.host != null) {
      for (final cam in snap.cams) {
        final d = haversineMetres(
          snap.host!.lat,
          snap.host!.lon,
          cam.lat,
          cam.lon,
        );
        if (d > range) continue;
        final isDanger = danger != null && danger.cam.id == cam.id;
        blips.add(SpeedcamRadarBlip(
          bearingDeg: initialBearingDegrees(
            snap.host!.lat,
            snap.host!.lon,
            cam.lat,
            cam.lon,
          ),
          distanceM: d,
          highlight: isDanger && danger.insideApproach,
          maxspeed: cam.maxspeed,
        ));
      }
      if (danger != null &&
          danger.insideApproach &&
          !blips.any((b) => b.highlight)) {
        blips.add(SpeedcamRadarBlip(
          bearingDeg: danger.bearingDeg,
          distanceM: danger.distanceM,
          highlight: true,
          maxspeed: danger.cam.maxspeed,
        ));
      }
    } else if (danger != null && danger.insideApproach) {
      blips.add(SpeedcamRadarBlip(
        bearingDeg: danger.bearingDeg,
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
              blips: blips,
              displayRadiusM: range,
              approachRadiusM: 500,
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
    // Relative: assume host heading folded into bearing already for danger.
    // Use absolute pie slices for demo.
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

/// Alien motion-tracker: front-hemisphere wedge, arcs, blips, sweep pulse.
class _AlienWedgePainter extends CustomPainter {
  _AlienWedgePainter({
    required this.sweepT,
    required this.blips,
    required this.displayRadiusM,
    required this.approachRadiusM,
    required this.readoutM,
    required this.maxspeed,
  });

  final double sweepT;
  final List<SpeedcamRadarBlip> blips;
  final double displayRadiusM;
  final double approachRadiusM;
  final double? readoutM;
  final int? maxspeed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.92);
    final r = math.min(size.width, size.height) * 0.88;

    // Dark phosphor ground
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020802),
    );

    // Scanlines
    final scan = Paint()..color = const Color(0x2200FF66);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }

    const wedgeHalf = 55 * math.pi / 180; // ~110° front hemisphere
    final baseAngle = -math.pi / 2; // up

    final wedgePath = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        baseAngle - wedgeHalf,
        wedgeHalf * 2,
        false,
      )
      ..close();

    canvas.drawPath(
      wedgePath,
      Paint()
        ..color = SpeedcamRadarWidget.phosphorDim.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      wedgePath,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Radial spokes
    for (var i = -2; i <= 2; i++) {
      final a = baseAngle + i * (wedgeHalf / 2);
      canvas.drawLine(
        c,
        Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
        Paint()
          ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    // Range arcs (dashed feel via segments)
    for (final frac in [0.33, 0.66, 1.0]) {
      final rr = r * frac;
      final paint = Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(
          alpha: frac == 1.0 ? 0.7 : 0.4,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = frac == 1.0 ? 1.8 : 1.1;
      const steps = 24;
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

    // Approach ring mark
    final approachFrac = (approachRadiusM / displayRadiusM).clamp(0.05, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * approachFrac),
      baseAngle - wedgeHalf,
      wedgeHalf * 2,
      false,
      Paint()
        ..color = SpeedcamRadarWidget.phosphorGlow.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Sweep pulse line across the wedge
    final sweepA = baseAngle - wedgeHalf + sweepT * wedgeHalf * 2;
    canvas.save();
    canvas.clipPath(wedgePath);
    canvas.drawLine(
      c,
      Offset(c.dx + r * math.cos(sweepA), c.dy + r * math.sin(sweepA)),
      Paint()
        ..color = SpeedcamRadarWidget.phosphorGlow.withValues(alpha: 0.65)
        ..strokeWidth = 2,
    );
    canvas.restore();

    // Origin pip
    canvas.drawCircle(c, 3, Paint()..color = SpeedcamRadarWidget.phosphorGlow);

    // Blips — map bearing so 0° is ahead (up)
    for (final b in blips) {
      final rel = _normalizeBearing(b.bearingDeg) * math.pi / 180;
      // bearing 0 = ahead = baseAngle; positive = right
      final a = baseAngle + rel;
      if (rel.abs() > wedgeHalf) continue;
      final frac = (b.distanceM / displayRadiusM).clamp(0.0, 1.0);
      final p = Offset(
        c.dx + r * frac * math.cos(a),
        c.dy + r * frac * math.sin(a),
      );
      final rad = b.highlight ? 5.0 : 3.0;
      canvas.drawCircle(
        p,
        rad + 2,
        Paint()
          ..color = SpeedcamRadarWidget.phosphorGlow.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        p,
        rad,
        Paint()
          ..color = b.highlight
              ? SpeedcamRadarWidget.phosphorGlow
              : SpeedcamRadarWidget.phosphor,
      );
    }

    // Readout
    if (readoutM != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: maxspeed != null
              ? '${readoutM!.round()} m  ·  $maxspeed'
              : '${readoutM!.round()} m',
          style: const TextStyle(
            color: SpeedcamRadarWidget.phosphor,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(6, size.height - tp.height - 4));
    }
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
      old.blips != blips ||
      old.displayRadiusM != displayRadiusM ||
      old.readoutM != readoutM ||
      old.maxspeed != maxspeed;
}

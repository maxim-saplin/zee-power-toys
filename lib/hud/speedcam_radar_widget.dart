import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/speedcam.dart';
import '../services/speedcam.dart';

enum SpeedcamRadarVariant { hudCompact, dhuLarge }

/// One blip on the CRT (relative to host).
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

/// Alien/CRT green radar — HUD compact slot or DHU large zoom-out (0033/0034).
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

  /// When true (DHU), paint CRT even with no danger / no pose.
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
      // Ensure danger blip present even if not in cams list (relay).
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

    final show = alwaysShow ||
        blips.any((b) => b.highlight) ||
        (variant == SpeedcamRadarVariant.hudCompact &&
            danger != null &&
            danger.insideApproach);

    if (!show) return const SizedBox.shrink();

    final controller = useAnimationController(
      duration: const Duration(seconds: 3),
    );
    useEffect(() {
      controller.repeat();
      return null;
    }, const []);

    SpeedcamRadarBlip? highlight;
    for (final b in blips) {
      if (b.highlight) {
        highlight = b;
        break;
      }
    }
    final labelDist = highlight?.distanceM ?? danger?.distanceM;
    final labelMax = highlight?.maxspeed ?? danger?.cam.maxspeed;

    final keyName = variant == SpeedcamRadarVariant.dhuLarge
        ? 'dhu-speedcam-radar'
        : 'hud-speedcam-radar';

    return Semantics(
      key: ValueKey(keyName),
      label: labelDist != null
          ? 'Speedcam radar ${labelDist.round()} metres'
          : 'Speedcam radar',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CrtRadarPainter(
              sweepT: controller.value,
              blips: blips,
              displayRadiusM: range,
              approachRadiusM: 500,
              readoutM: labelDist,
              maxspeed: labelMax,
              showApproachRing: true,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CrtRadarPainter extends CustomPainter {
  _CrtRadarPainter({
    required this.sweepT,
    required this.blips,
    required this.displayRadiusM,
    required this.approachRadiusM,
    this.readoutM,
    this.maxspeed,
    this.showApproachRing = true,
  });

  final double sweepT;
  final List<SpeedcamRadarBlip> blips;
  final double displayRadiusM;
  final double approachRadiusM;
  final double? readoutM;
  final int? maxspeed;
  final bool showApproachRing;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height * 0.46);
    final r = side * 0.42;

    final bezel = Paint()
      ..color = SpeedcamRadarWidget.phosphorDim.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, bezel);

    final ring = Paint()
      ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, r * 0.33, ring);
    canvas.drawCircle(c, r * 0.66, ring);
    canvas.drawCircle(c, r, ring);

    // Approach ring (500 m) inside zoom-out display
    if (showApproachRing && displayRadiusM > approachRadiusM) {
      final ar = r * (approachRadiusM / displayRadiusM);
      canvas.drawCircle(
        c,
        ar,
        Paint()
          ..color = SpeedcamRadarWidget.phosphorGlow.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final cross = Paint()
      ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);

    final sweepAngle = sweepT * 2 * math.pi - math.pi / 2;
    final sweepPath = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        sweepAngle - 0.35,
        0.35,
        false,
      )
      ..close();
    canvas.drawPath(
      sweepPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SpeedcamRadarWidget.phosphor.withValues(alpha: 0.35),
            SpeedcamRadarWidget.phosphor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawLine(
      c,
      Offset(
        c.dx + r * math.cos(sweepAngle),
        c.dy + r * math.sin(sweepAngle),
      ),
      Paint()
        ..color = SpeedcamRadarWidget.phosphorGlow
        ..strokeWidth = 1.5,
    );

    // Host centre pip
    canvas.drawCircle(c, 2.5, Paint()..color = SpeedcamRadarWidget.phosphor);

    for (final blip in blips) {
      final rangeFrac = (blip.distanceM / displayRadiusM).clamp(0.0, 1.0);
      final blipAngle = blip.bearingDeg * math.pi / 180 - math.pi / 2;
      final blipR = r * rangeFrac;
      final pos = Offset(
        c.dx + blipR * math.cos(blipAngle),
        c.dy + blipR * math.sin(blipAngle),
      );
      final radius = blip.highlight ? 5.0 : 3.0;
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = blip.highlight
              ? SpeedcamRadarWidget.phosphorGlow
              : SpeedcamRadarWidget.phosphor.withValues(alpha: 0.55),
      );
      if (blip.highlight) {
        canvas.drawCircle(
          pos,
          10,
          Paint()
            ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    final parts = <String>[];
    if (readoutM != null) parts.add('${readoutM!.round()} m');
    if (maxspeed != null) parts.add('$maxspeed');
    parts.add('${displayRadiusM.round()} m rng');
    final label = parts.join(' · ');
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: SpeedcamRadarWidget.phosphor,
          fontSize: size.shortestSide < 140 ? 10 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + r + 4));

    final scan = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var y = c.dy - r; y < c.dy + r; y += 3) {
      canvas.drawLine(Offset(c.dx - r, y), Offset(c.dx + r, y), scan);
    }
  }

  @override
  bool shouldRepaint(covariant _CrtRadarPainter old) =>
      old.sweepT != sweepT ||
      old.displayRadiusM != displayRadiusM ||
      old.readoutM != readoutM ||
      old.maxspeed != maxspeed ||
      old.blips.length != blips.length;
}

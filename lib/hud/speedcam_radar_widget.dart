import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/speedcam.dart';
import '../services/speedcam.dart';

/// Alien/CRT green radar for the HUD right slot (0033).
///
/// Emissive only — black elsewhere. Hidden when no [SpeedcamDanger] with
/// [SpeedcamDanger.insideApproach] (idle windshield stays black), unless
/// [forceDemoDanger] is set (Config Preview).
class SpeedcamRadarWidget extends HookConsumerWidget {
  const SpeedcamRadarWidget({super.key, this.forceDemoDanger});

  /// When non-null, paints this danger instead of the live provider (preview).
  final SpeedcamDanger? forceDemoDanger;

  static const Color phosphor = Color(0xFF39FF14);
  static const Color phosphorDim = Color(0xFF1A7A0A);
  static const Color phosphorGlow = Color(0xFF00FF66);

  /// Demo cam ~200 m ahead-right for Config Preview.
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
    final live = ref.watch(speedcamDangerProvider);
    final danger = forceDemoDanger ?? live;
    if (danger == null || !danger.insideApproach) {
      return const SizedBox.shrink();
    }

    final controller = useAnimationController(
      duration: const Duration(seconds: 3),
    );
    useEffect(() {
      controller.repeat();
      return null;
    }, const []);

    return Semantics(
      key: const ValueKey('hud-speedcam-radar'),
      label: 'Speedcam radar ${danger.distanceM.round()} metres',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CrtRadarPainter(
              sweepT: controller.value,
              bearingDeg: danger.bearingDeg,
              distanceM: danger.distanceM,
              approachRadiusM: 500,
              maxspeed: danger.cam.maxspeed,
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
    required this.bearingDeg,
    required this.distanceM,
    required this.approachRadiusM,
    this.maxspeed,
  });

  final double sweepT;
  final double bearingDeg;
  final double distanceM;
  final double approachRadiusM;
  final int? maxspeed;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final r = side * 0.46;

    // Outer CRT bezel glow
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

    // Crosshairs
    final cross = Paint()
      ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);

    // Sweep wedge (Alien locator)
    final sweepAngle = sweepT * 2 * math.pi - math.pi / 2; // 0 = north
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
    final sweepLine = Paint()
      ..color = SpeedcamRadarWidget.phosphorGlow
      ..strokeWidth = 1.5;
    canvas.drawLine(
      c,
      Offset(
        c.dx + r * math.cos(sweepAngle),
        c.dy + r * math.sin(sweepAngle),
      ),
      sweepLine,
    );

    // Blip at bearing / range (0 at center, 1 at approach radius)
    final rangeFrac = (distanceM / approachRadiusM).clamp(0.0, 1.0);
    final blipAngle = bearingDeg * math.pi / 180 - math.pi / 2;
    final blipR = r * rangeFrac;
    final blip = Offset(
      c.dx + blipR * math.cos(blipAngle),
      c.dy + blipR * math.sin(blipAngle),
    );
    canvas.drawCircle(
      blip,
      4,
      Paint()..color = SpeedcamRadarWidget.phosphorGlow,
    );
    canvas.drawCircle(
      blip,
      8,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Distance / limit readout under disc
    final label = maxspeed != null
        ? '${distanceM.round()} m · $maxspeed'
        : '${distanceM.round()} m';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: SpeedcamRadarWidget.phosphor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset(c.dx - tp.width / 2, c.dy + r + 2),
    );

    // Light scanlines
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
      old.bearingDeg != bearingDeg ||
      old.distanceM != distanceM ||
      old.maxspeed != maxspeed;
}

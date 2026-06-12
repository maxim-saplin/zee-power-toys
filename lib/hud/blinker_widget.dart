import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/car_signals.dart';
import '../services/config_store.dart';

/// Emissive yellow blinker indicator for the HUD BLINKER slot.
///
/// Watches [blinkerProvider] and [blinkerConfigProvider].  Renders the active
/// side(s) with the configured shape and blink cadence.  Nothing is drawn (or
/// animated) when the blinker is off — no always-on timers (ADR 0003).
///
/// Emissive yellow: [_kAmber] ≈ #FFC107, matching phase0 hud_amber.  Emissive
/// rendering rule: no light backgrounds — the widget is transparent except for
/// the bright marks themselves.
///
/// Sizing: a real dashboard turn indicator is *small* — a neat amber dot near
/// the edge, not a billboard.  The mark uses a fixed logical diameter
/// ([_kBaseDiameter]) scaled by [BlinkerConfig.sizeScale], so it stays a tidy
/// indicator regardless of how tall the Safe Area / slot is.  Marks sit near
/// the left/right edges of the slot, vertically centred via
/// [BlinkerConfig.vertFrac].
///
/// Blink cadence: 450ms on/off — the embedded BlinkerOverlayView value
/// (production path, more in sync with real-car BCM 120 BPM cadence than the
/// 500ms standalone diagnostic activities).
class BlinkerWidget extends HookConsumerWidget {
  const BlinkerWidget({super.key});

  // Phase0 hud_amber: #FFC107.  Slightly warmer than Material Yellow 500
  // (#FFEB3B) — matches the physical HUD amber exactly.
  static const Color _kAmber = Color(0xFFFFC107);

  // 450ms matches BlinkerOverlayView.BLINK_INTERVAL_MS (production embedded value).
  static const Duration _kBlinkHalf = Duration(milliseconds: 450);

  /// Base mark diameter in logical px at sizeScale = 1.0.  Sized like a real
  /// dashboard turn indicator (small + crisp at 160dpi), NOT a slot fraction —
  /// so it never bloats with a tall Safe Area.  The arrow/smiley shapes derive
  /// their footprint from this same unit so every shape reads at one scale.
  static const double _kBaseDiameter = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(blinkerProvider);
    final cfg = ref.watch(blinkerConfigProvider);

    final isActive = state != BlinkerState.off;

    // AnimationController runs only while the blinker is active (no idle timers).
    // repeat() drives a 0→1 tween; we use the integer blink counter to toggle.
    final controller = useAnimationController(
      duration: _kBlinkHalf,
      // Start immediately when active so the first frame is visible.
      initialValue: isActive ? 0.0 : 0.0,
    );

    // Effect: start/stop the repeat animation in sync with active state.
    // useEffect re-runs whenever [isActive] changes.
    useEffect(() {
      if (isActive) {
        controller.repeat();
      } else {
        controller.stop();
        controller.value = 0.0;
      }
      return null;
    }, [isActive]);

    // Blink: true on every even cycle (controller completes one half-cycle →
    // increments; we derive on/off from the current animation status + value).
    // A simpler approach: listen to the AnimationStatus and toggle a local bool.
    final blinkOn = useState(true);
    useEffect(() {
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          // Flip on each half-cycle completion.
          blinkOn.value = !blinkOn.value;
          controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          blinkOn.value = !blinkOn.value;
          controller.forward();
        }
      }
      controller.addStatusListener(listener);
      return () => controller.removeStatusListener(listener);
    }, [controller]);

    if (!isActive) return const SizedBox.shrink();

    final showLeft = state == BlinkerState.left || state == BlinkerState.hazard;
    final showRight = state == BlinkerState.right || state == BlinkerState.hazard;

    // The BLINKER slot fills the available box; we position marks inside it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotW = constraints.maxWidth;
        final slotH = constraints.maxHeight;

        // Small fixed-ish diameter — a neat indicator, never a billboard.
        // Clamp against the slot so it can't overflow a very short slot, but
        // otherwise it stays the calibrated small size.
        final diameter =
            (_kBaseDiameter * cfg.sizeScale).clamp(8.0, slotH * 0.5);

        final vertCenter = slotH * cfg.vertFrac;
        // Horizontal: sidePadFrac is inward from the outer slot edge.
        final padX = slotW * cfg.sidePadFrac;

        final color = blinkOn.value ? _kAmber : Colors.transparent;

        return Stack(
          children: <Widget>[
            if (showLeft)
              Positioned(
                left: padX,
                top: vertCenter - _markHeight(cfg.shape, diameter) / 2,
                child: _BlinkerMark(
                  key: const ValueKey('blinker-mark-left'),
                  shape: cfg.shape,
                  diameter: diameter,
                  color: color,
                  side: _Side.left,
                ),
              ),
            if (showRight)
              Positioned(
                right: padX,
                top: vertCenter - _markHeight(cfg.shape, diameter) / 2,
                child: _BlinkerMark(
                  key: const ValueKey('blinker-mark-right'),
                  shape: cfg.shape,
                  diameter: diameter,
                  color: color,
                  side: _Side.right,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Rendered height of a mark for the given shape, used to vertically centre
  /// it.  All shapes are normalised around [diameter] so they stay small.
  static double _markHeight(BlinkerShape shape, double diameter) {
    switch (shape) {
      case BlinkerShape.dots:
        return diameter; // single circle
      case BlinkerShape.arrows:
        return diameter; // chevron drawn in a diameter-tall box
      case BlinkerShape.smiley:
        return diameter; // smiley drawn in a diameter box
    }
  }
}

enum _Side { left, right }

/// A single blinker mark (left or right) rendered as the configured shape.
///
/// [diameter] is the small base size shared by all shapes so each reads as a
/// neat indicator rather than a slot-filling billboard.
class _BlinkerMark extends StatelessWidget {
  const _BlinkerMark({
    super.key,
    required this.shape,
    required this.diameter,
    required this.color,
    required this.side,
  });

  final BlinkerShape shape;
  final double diameter;
  final Color color;
  final _Side side;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case BlinkerShape.dots:
        return _CircleShape(diameter: diameter, color: color);
      case BlinkerShape.arrows:
        return _ArrowShape(diameter: diameter, color: color, side: side);
      case BlinkerShape.smiley:
        return _SmileyShape(diameter: diameter, color: color);
    }
  }
}

// ---------------------------------------------------------------------------
// Shape: circle (default — "dots")
// ---------------------------------------------------------------------------

/// A single small amber circle — the default blinker mark.
///
/// Real dashboard turn indicators are small, clean circles; one neat dot per
/// active side reads at a glance without dominating the HUD.  (The shape enum
/// value is still named `dots` for config compatibility.)
class _CircleShape extends StatelessWidget {
  const _CircleShape({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shape: arrows
// ---------------------------------------------------------------------------

/// A small neat turn-arrow chevron — ported from phase0 ic_blinker_left/right.
///
/// Original SVG viewport 120×60; left path: M110,10 L50,10 L20,30 L50,50 L110,50
/// L110,38 L70,38 L70,22 L110,22 Z.  Right: mirror.  We render it in a compact
/// [1.4·diameter × diameter] box so it preserves the chevron aspect ratio while
/// staying the same small scale as the circle.
class _ArrowShape extends StatelessWidget {
  const _ArrowShape({
    required this.diameter,
    required this.color,
    required this.side,
  });

  final double diameter;
  final Color color;
  final _Side side;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter * 1.4,
      height: diameter,
      child: CustomPaint(
        painter: _ArrowPainter(color: color, side: side),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.side});
  final Color color;
  final _Side side;

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Scale phase0 120×60 viewport to our canvas size.
    final scaleX = size.width / 120.0;
    final scaleY = size.height / 60.0;

    Path p;
    if (side == _Side.left) {
      // Left arrow: M110,10 L50,10 L20,30 L50,50 L110,50 L110,38 L70,38 L70,22 L110,22 Z
      p = Path()
        ..moveTo(110 * scaleX, 10 * scaleY)
        ..lineTo(50 * scaleX, 10 * scaleY)
        ..lineTo(20 * scaleX, 30 * scaleY)
        ..lineTo(50 * scaleX, 50 * scaleY)
        ..lineTo(110 * scaleX, 50 * scaleY)
        ..lineTo(110 * scaleX, 38 * scaleY)
        ..lineTo(70 * scaleX, 38 * scaleY)
        ..lineTo(70 * scaleX, 22 * scaleY)
        ..lineTo(110 * scaleX, 22 * scaleY)
        ..close();
    } else {
      // Right arrow: M10,10 L70,10 L100,30 L70,50 L10,50 L10,38 L50,38 L50,22 L10,22 Z
      p = Path()
        ..moveTo(10 * scaleX, 10 * scaleY)
        ..lineTo(70 * scaleX, 10 * scaleY)
        ..lineTo(100 * scaleX, 30 * scaleY)
        ..lineTo(70 * scaleX, 50 * scaleY)
        ..lineTo(10 * scaleX, 50 * scaleY)
        ..lineTo(10 * scaleX, 38 * scaleY)
        ..lineTo(50 * scaleX, 38 * scaleY)
        ..lineTo(50 * scaleX, 22 * scaleY)
        ..lineTo(10 * scaleX, 22 * scaleY)
        ..close();
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.side != side;
}

// ---------------------------------------------------------------------------
// Shape: smiley
// ---------------------------------------------------------------------------

/// A small yellow smiley face — per REQUIREMENTS "yellow smileys".
///
/// Rendered at the same small [diameter] as the circle so it reads as a neat
/// indicator.  Filled amber face with two dot eyes and a curved mouth in a
/// darker amber so features read as cutouts on the projector without emitting
/// bright whites (emissive-on-black rule: no light backgrounds).
class _SmileyShape extends StatelessWidget {
  const _SmileyShape({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _SmileyPainter(color: color),
      ),
    );
  }
}

class _SmileyPainter extends CustomPainter {
  const _SmileyPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Face fill — full amber circle.
    final facePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, facePaint);

    // Face features drawn in a darker amber so they read as cutouts on the
    // projector (contrast against the amber fill, no bright white).
    final featurePaint = Paint()
      ..color = const Color(0xFF7A5C00) // dark amber / brown
      ..style = PaintingStyle.fill;

    final eyeR = r * 0.14;
    final eyeY = cy - r * 0.22;
    canvas.drawCircle(Offset(cx - r * 0.32, eyeY), eyeR, featurePaint);
    canvas.drawCircle(Offset(cx + r * 0.32, eyeY), eyeR, featurePaint);

    // Smile arc.
    final mouthPaint = Paint()
      ..color = const Color(0xFF7A5C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.05),
      width: r * 0.95,
      height: r * 0.60,
    );
    canvas.drawArc(mouthRect, math.pi * 0.15, math.pi * 0.70, false, mouthPaint);
  }

  @override
  bool shouldRepaint(_SmileyPainter old) => old.color != color;
}

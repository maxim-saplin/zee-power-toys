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

        // Base size calibrated to the slot height; scaled by user config.
        // phase0 dot = 12dp; the slot height at the reference 616×175dp HUD is
        // ~175*0.6 ≈ 105dp, so 12/105 ≈ 0.11 → use 0.12 for comfortable visibility.
        final baseSize = slotH * 0.12 * cfg.sizeScale;

        final vertCenter = slotH * cfg.vertFrac;
        // Horizontal: sidePadFrac is inward from the outer slot edge.
        final padX = slotW * cfg.sidePadFrac;

        final color = blinkOn.value ? _kAmber : Colors.transparent;

        return Stack(
          children: <Widget>[
            if (showLeft)
              Positioned(
                left: padX,
                top: vertCenter - baseSize * _shapeVertHalf(cfg.shape),
                child: _BlinkerMark(
                  key: const ValueKey('blinker-mark-left'),
                  shape: cfg.shape,
                  size: baseSize,
                  color: color,
                  side: _Side.left,
                ),
              ),
            if (showRight)
              Positioned(
                right: padX,
                top: vertCenter - baseSize * _shapeVertHalf(cfg.shape),
                child: _BlinkerMark(
                  key: const ValueKey('blinker-mark-right'),
                  shape: cfg.shape,
                  size: baseSize,
                  color: color,
                  side: _Side.right,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Half-height multiplier for each shape — used to vertically center the mark.
  static double _shapeVertHalf(BlinkerShape shape) {
    switch (shape) {
      case BlinkerShape.dots:
        return 1.5; // stack of 3 dots
      case BlinkerShape.arrows:
        return 0.5; // single chevron height ≈ baseSize * 1.0
      case BlinkerShape.smiley:
        return 1.0; // circle diameter = 2 * baseSize
    }
  }
}

enum _Side { left, right }

/// A single blinker mark (left or right) rendered as the configured shape.
class _BlinkerMark extends StatelessWidget {
  const _BlinkerMark({
    super.key,
    required this.shape,
    required this.size,
    required this.color,
    required this.side,
  });

  final BlinkerShape shape;
  final double size;
  final Color color;
  final _Side side;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case BlinkerShape.dots:
        return _DotsShape(size: size, color: color);
      case BlinkerShape.arrows:
        return _ArrowShape(size: size, color: color, side: side);
      case BlinkerShape.smiley:
        return _SmileyShape(size: size, color: color);
    }
  }
}

// ---------------------------------------------------------------------------
// Shape: dots
// ---------------------------------------------------------------------------

/// Three stacked amber dots — faithful port of phase0 BlinkerOverlayView.
///
/// phase0 used a single 12dp oval per side.  The "beautiful" name in
/// HudBeautifulBlinkerActivity suggests a cluster; we render three dots
/// (top/mid/bottom) to evoke the cluster aesthetic while staying readable.
class _DotsShape extends StatelessWidget {
  const _DotsShape({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Three dots stacked vertically with a small gap.
    final gap = size * 0.3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Dot(size: size, color: color),
        SizedBox(height: gap),
        _Dot(size: size, color: color),
        SizedBox(height: gap),
        _Dot(size: size, color: color),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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

/// Turn-arrow chevron — ported from phase0 ic_blinker_left / ic_blinker_right.
///
/// Original SVG viewport 120×60; left path: M110,10 L50,10 L20,30 L50,50 L110,50
/// L110,38 L70,38 L70,22 L110,22 Z.  Right: mirror.
/// We scale this into a [size × size/2] bounding box for a compact HUD mark.
class _ArrowShape extends StatelessWidget {
  const _ArrowShape({
    required this.size,
    required this.color,
    required this.side,
  });

  final double size;
  final Color color;
  final _Side side;

  @override
  Widget build(BuildContext context) {
    // Arrow width = 2 * size to preserve the 120:60 aspect ratio.
    return SizedBox(
      width: size * 2,
      height: size,
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

/// Yellow smiley face — new shape per REQUIREMENTS "yellow smileys".
///
/// Design: filled amber circle with two dot eyes and a curved mouth,
/// all in a darker amber so the face reads on the projector without
/// emitting bright whites (emissive-on-black rule: no light backgrounds).
class _SmileyShape extends StatelessWidget {
  const _SmileyShape({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Diameter = 2 * size so the smiley is a generous mark.
    final diameter = size * 2;
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

    final eyeR = r * 0.12;
    final eyeY = cy - r * 0.22;
    canvas.drawCircle(Offset(cx - r * 0.30, eyeY), eyeR, featurePaint);
    canvas.drawCircle(Offset(cx + r * 0.30, eyeY), eyeR, featurePaint);

    // Smile arc.
    final mouthPaint = Paint()
      ..color = const Color(0xFF7A5C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.05),
      width: r * 0.90,
      height: r * 0.55,
    );
    canvas.drawArc(mouthRect, math.pi * 0.15, math.pi * 0.70, false, mouthPaint);
  }

  @override
  bool shouldRepaint(_SmileyPainter old) => old.color != color;
}

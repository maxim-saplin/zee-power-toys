import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'blinker_geometry.dart';
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
/// ([kBlinkerBaseDiameter], via [blinkerMarkDiameter]) scaled by
/// [BlinkerConfig.sizeScale], so it stays a tidy indicator regardless of how
/// tall the Safe Area / slot is.  Marks sit near the left/right edges of the
/// slot, vertically centred via [BlinkerConfig.vertFrac].
///
/// Blink cadence: 450ms on/off — the embedded BlinkerOverlayView value
/// (production path, more in sync with real-car BCM 120 BPM cadence than the
/// 500ms standalone diagnostic activities).  The blink state is a pure
/// function of elapsed time ([blinkOnAt]), driven off the repeating
/// [AnimationController]'s current value — see the `build` method for why
/// that indirection is needed: `repeat()` never emits
/// `AnimationStatus.completed`/`.dismissed`, so nothing may derive blink
/// state from animation *status*, only from elapsed time.
class BlinkerWidget extends HookConsumerWidget {
  const BlinkerWidget({super.key, this.forceBlinkOn});

  /// Test-only escape hatch: when non-null, bypasses the blink-cadence
  /// animation entirely and renders on/off exactly as given, so widget tests
  /// don't need to pump real wall-clock time to reach a specific phase of the
  /// blink cycle. Left `null` in production.
  @visibleForTesting
  final bool? forceBlinkOn;

  // Phase0 hud_amber: #FFC107.  Slightly warmer than Material Yellow 500
  // (#FFEB3B) — matches the physical HUD amber exactly.
  static const Color _kAmber = Color(0xFFFFC107);

  // 450ms matches BlinkerOverlayView.BLINK_INTERVAL_MS (production embedded value).
  static const Duration _kBlinkHalf = kBlinkerHalfCycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(blinkerProvider);
    final cfg = ref.watch(blinkerConfigProvider);

    final isActive = state != BlinkerState.off;

    // AnimationController runs only while the blinker is active (no idle
    // timers) — repeat() over one full blink cycle (2 × _kBlinkHalf: on then
    // off). Bug fixed here: repeat() never emits AnimationStatus.completed or
    // .dismissed (it just loops value 0→1 forever), so blink state can never
    // be derived from animation *status* — the previous status-listener
    // driver was dead code and the mark rendered steady on. blinkOnAt() below
    // derives blink state from elapsed time instead, which is what actually
    // changes every tick.
    final cyclePeriod = _kBlinkHalf * 2;
    final controller = useAnimationController(duration: cyclePeriod);

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

    // useAnimation subscribes to the controller so this widget rebuilds every
    // tick while it repeats — without this, nothing reads controller.value
    // and the widget never repaints even though the controller is running.
    // Called unconditionally (regardless of forceBlinkOn) to keep hook-call
    // order stable across rebuilds of the same widget instance.
    final animValue = useAnimation(controller);

    // forceBlinkOn (test-only) bypasses the animation entirely; otherwise
    // blink state is elapsed-time-within-cycle fed through the shared pure
    // function, so the same cadence is exercised deterministically in tests
    // via blinkOnAt() directly.
    final blinkOn = forceBlinkOn ??
        blinkOnAt(
          Duration(microseconds: (animValue * cyclePeriod.inMicroseconds).round()),
          half: _kBlinkHalf,
        );

    if (!isActive) return const SizedBox.shrink();

    final showLeft = state == BlinkerState.left || state == BlinkerState.hazard;
    final showRight = state == BlinkerState.right || state == BlinkerState.hazard;

    // The BLINKER slot fills the available box; we position marks inside it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotW = constraints.maxWidth;
        final slotH = constraints.maxHeight;

        // Small fixed-ish diameter — a neat indicator, never a billboard.
        // Clamped against the slot (see blinkerMarkDiameter) so it can't
        // overflow a very short slot, but otherwise stays the calibrated
        // small size.
        final diameter = blinkerMarkDiameter(slotH: slotH, sizeScale: cfg.sizeScale);
        final box = blinkerMarkBox(cfg.shape, diameter);

        final vertCenter = slotH * cfg.vertFrac;
        // Horizontal: sidePadFrac is inward from the outer slot edge.
        final padX = slotW * cfg.sidePadFrac;

        final color = blinkOn ? _kAmber : Colors.transparent;

        return Stack(
          children: <Widget>[
            if (showLeft)
              Positioned(
                left: padX,
                top: vertCenter - box.height / 2,
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
                top: vertCenter - box.height / 2,
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

/// A small solid turn-signal triangle — the ISO 2575 idiom, tip pointing
/// outward. Geometry lives in [blinkerArrowPath]; see its doc comment for why
/// this has no tail (an earlier tailed pentagon read as a banner, not an
/// indicator, and any tail detail mushes to nothing at this mark's small
/// default size on an emissive projector). Rendered in a compact
/// [1.2·diameter × diameter] box (via [blinkerMarkBox]) — wide enough to show
/// the taper, small enough to stay a neat indicator like the circle.
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
    final box = blinkerMarkBox(BlinkerShape.arrows, diameter);
    return SizedBox(
      width: box.width,
      height: box.height,
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
    canvas.drawPath(
      blinkerArrowPath(size, isLeft: side == _Side.left),
      paint,
    );
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
    //
    // Sizing: at the default mark size (kBlinkerBaseDiameter = 18px, r = 9),
    // the original 0.14·r eye radius / stroke width worked out to ~1.26
    // logical px — sub-2px detail that mushes into a faint smear on this
    // emissive projector rather than reading as an eye or a mouth (fine
    // detail disappears; see CONTEXT.md). Scaled up to ~0.20–0.22·r (~1.8–2px
    // at r=9), the features clear that floor while a) staying clearly
    // smaller than the face itself and b) not overlapping each other or the
    // face edge (checked: two eyes at ±0.32·r offset with 0.22·r radius sit
    // well inside the r=9 face, no overlap).
    final featurePaint = Paint()
      ..color = const Color(0xFF7A5C00) // dark amber / brown
      ..style = PaintingStyle.fill;

    final eyeR = r * 0.22;
    final eyeY = cy - r * 0.22;
    canvas.drawCircle(Offset(cx - r * 0.32, eyeY), eyeR, featurePaint);
    canvas.drawCircle(Offset(cx + r * 0.32, eyeY), eyeR, featurePaint);

    // Smile arc.
    final mouthPaint = Paint()
      ..color = const Color(0xFF7A5C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.26
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

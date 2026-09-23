import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/speedcam.dart';
import '../services/config_store.dart';
import '../services/speedcam.dart';
import 'speedcam_crt_geometry.dart';

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
    this.lookOverride,
  });

  final SpeedcamDanger? forceDemoDanger;
  final SpeedcamRadarVariant variant;

  /// Outer ring metres (DHU zoom-out). Defaults: HUD 500, DHU from config.
  final double? displayRadiusM;

  /// When true (DHU), paint even with no danger / no pose.
  final bool alwaysShow;

  /// Optional look pin (T1 desktop HUD demo → Alien). Null = config look.
  final SpeedcamRadarLook? lookOverride;

  static const Color phosphor = Color(0xFF39FF14);
  static const Color phosphorDim = Color(0xFF1A7A0A);
  static const Color phosphorGlow = Color(0xFF00FF66);

  /// Dangerous / current target blip (0064).
  static const Color blipDanger = Color(0xFFFFFFFF);

  /// Other in-range scan blips — greenish phosphor (0064).
  static const Color blipOther = phosphor;

  /// Same pose/limit as HUD Demo + agent approach ([kSpeedcamDemoMaxspeed]).
  static final demoDanger = SpeedcamDanger(
    cam: const SpeedcamPoint(
      id: 'demo-cam',
      lat: 53.9,
      lon: 27.56,
      maxspeed: kSpeedcamDemoMaxspeed,
    ),
    distanceM: kSpeedcamDemoDistanceM,
    bearingDeg: kSpeedcamDemoBearingDeg,
    insideApproach: true,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(speedcamConfigProvider);
    // 0060: HUD Off → no paint on windshield (DHU preview still shows via alwaysShow).
    if (variant == SpeedcamRadarVariant.hudCompact &&
        cfg.hudMode == SpeedcamPresenceMode.off) {
      return const SizedBox.shrink();
    }

    final snap = ref.watch(speedcamSnapshotProvider);
    final liveDanger = ref.watch(speedcamDangerProvider);
    final approachM = snap.approachRadiusM > 0
        ? snap.approachRadiusM
        : cfg.dhuRangeM;
    // Presence selection for HUD channel (independent of sound mode).
    final modeDanger = forceDemoDanger ??
        resolvePresenceDanger(
          mode: cfg.hudMode,
          host: snap.host,
          cams: snap.cams,
          approachRadiusM: approachM,
          serviceDanger: liveDanger,
        );
    final danger = forceDemoDanger ?? modeDanger;
    final look = lookOverride ?? cfg.radarLook;

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
    } else if (snap.host != null && cfg.hudMode != SpeedcamPresenceMode.off) {
      final host = snap.host!;
      final heading = host.headingDeg;
      for (final cam in snap.cams) {
        final d = haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
        if (d > range) continue;
        final absBearing =
            initialBearingDegrees(host.lat, host.lon, cam.lat, cam.lon);
        // Front-hemisphere scan for candidates (0060).
        if (!isCamAheadOfTravel(host, absBearing)) continue;
        // Dangerous HUD: facing mute; Any: show all ahead blips.
        if (cfg.hudMode == SpeedcamPresenceMode.dangerous &&
            !isCamRelevantForHost(host, cam)) {
          continue;
        }
        final isDanger = danger != null && danger.cam.id == cam.id;
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
          // 0083 Maxim: one canonical CRT paint (300×220), then uniform
          // FittedBox into the HUD / preview / Overlay slot. TextPainter +
          // strokes always see the same Size → glyph/min matches across
          // surfaces (no small-slot TextPainter metric drift).
          return FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: kSpeedcamCrtPlateW,
              height: kSpeedcamCrtPlateH,
              child: CustomPaint(
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
              ),
            ),
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
    // Dangerous / approach target readout is white (0064; Default has no multi-blip).
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: compact ? 18 : 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      shadows: const [
        Shadow(blurRadius: 4, color: Colors.black87),
      ],
    );
    // 0080: square HUD radar slot can be shorter than Default text stack
    // under HudPreview letterbox — scaleDown instead of RenderFlex overflow.
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: compact ? 8 : 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
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

/// 0064: dangerous highlight → white; other scan-set cams → greenish.
Color alienBlipFillColor({required bool highlight}) => highlight
    ? SpeedcamRadarWidget.blipDanger
    : SpeedcamRadarWidget.blipOther;


/// 0083 Maxim — Alien CRT paint is DPI-agnostic (vector + text from plate size).
/// Kept as identity for call-site compatibility; do not reintroduce density boosts.
double alienDhuDpiBridge({
  required double devicePixelRatio,
  required double surfaceLogicalWidth,
}) {
  return 1.0;
}

/// Plate-relative CRT scale. Alien paint always receives the canonical
/// [kSpeedcamCrtPlateW]×[kSpeedcamCrtPlateH] Size (then FittedBox scales).
/// Design side matches the windshield gold tune (~160 logical).
double alienCrtPlateScale(Size size) {
  final minSide = size.shortestSide;
  assert(minSide > 0);
  return minSide / 160.0;
}

/// Design km font at [alienCrtPlateScale] = 1. Fraction of design side ≈ 0.24
/// (classic pre-6788dc5 HUD glyph/min). Limit keeps ~20.7/39.1 of km.
const double kAlienCrtKmDesignFont = 39.1;
const double kAlienCrtLimitDesignFont = 20.7;

/// Alien motion-tracker: prop fan + expanding range rings from center + grit.
///
/// 0083 Maxim: **DPI-agnostic** vector + text. All strokes and km/limit scale
/// only from CRT plate [Size] (min side / design). No dpr bridge, no min-scale
/// floor (that made small HUD/preview type larger than Overlay). Fan outline +
/// readout are NOT clipped by the rounded CRT glass.
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

  /// Design size where HUD-gold strokes (~1.1–3.2) were tuned (windshield CRT).
  static const double _designSide = 160.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final minSide = math.min(size.width, size.height);
    final s = alienCrtPlateScale(size);

    // Bezel / outside CRT
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF0A0A0A));

    final crtRRect = RRect.fromRectAndRadius(
      bounds.deflate(1.5 * s),
      Radius.circular(minSide * 0.10),
    );

    // Landscape CRT (300×220): EVEN pad around horizontal fan on all four
    // sides (Maxim). Large km overlaps fan apex modestly — do NOT shrink the
    // fan for a text strip (that broke padding).
    const wedgeHalf = 50 * math.pi / 180;
    final tipLeft = -math.pi / 2 - wedgeHalf;
    final tipRight = -math.pi / 2 + wedgeHalf;
    final strokePad = 3.0 * s;
    final pad = math.max(math.min(size.width, size.height) * 0.06, 1.5 * s + strokePad);
    final inner = Rect.fromLTWH(
      pad,
      pad,
      size.width - 2 * pad,
      size.height - 2 * pad,
    );
    final sinHalf = math.sin(wedgeHalf);
    final rFromW = inner.width / (2 * sinHalf);
    final rFromH = inner.height; // bbox height == r
    final r = math.min(rFromW, rFromH);
    final fanW = 2 * r * sinHalf;
    final fanH = r;
    // Center fan bbox inside inner → even leftover pad L/R/T/B.
    final fanLeft = inner.left + (inner.width - fanW) / 2;
    final fanTop = inner.top + (inner.height - fanH) / 2;
    final c = Offset(fanLeft + fanW / 2, fanTop + fanH);
    assert((tipRight + tipLeft + math.pi).abs() < 1e-9);

    // Ground + grit + scan ONLY — rounded clip must not touch fan strokes.
    canvas.saveLayer(bounds, Paint());
    canvas.clipRRect(crtRRect, doAntiAlias: true);
    canvas.drawRRect(crtRRect, Paint()..color = const Color(0xFF010401));

    final grit = Paint()
      ..color = const Color(0x2200FF44)
      ..isAntiAlias = false;
    final gritN = (140 * (minSide * minSide) / (_designSide * _designSide))
        .round()
        .clamp(140, 520);
    final gritSide = 1.1 * s;
    for (var i = 0; i < gritN; i++) {
      final x = ((i * 131) % 997) / 997.0 * size.width;
      final y = ((i * 89) % 991) / 991.0 * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, gritSide, gritSide), grit);
    }

    final scan = Paint()
      ..color = const Color(0x3300FF55)
      ..strokeWidth = math.max(1.0, 1.0 * s)
      ..isAntiAlias = false;
    final scanStep = math.max(1.5, 2.0 * s);
    for (var y = 0.0; y < size.height; y += scanStep) {
      final ny = (y / size.height) * 2 - 1;
      final bow = 3.5 * s * ny * ny;
      canvas.drawLine(Offset(bow, y), Offset(size.width - bow, y), scan);
    }
    canvas.restore();

    // Fan + blips + ring — inside CRT (fit r above + clip belt).
    // Prior unclipped path spilled past CRT on DHU; clip must not shave the
    // outer arc when r is fit-constrained.
    final baseAngle = -math.pi / 2;
    canvas.save();
    canvas.clipRRect(crtRRect, doAntiAlias: true);
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
        ..color = const Color(0xFF0A3D0A).withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      wedgePath,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..isAntiAlias = false,
    );

    for (var i = -2; i <= 2; i++) {
      if (i == 0) continue;
      final a = baseAngle + i * (wedgeHalf / 2);
      canvas.drawLine(
        c,
        Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
        Paint()
          ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.4)
          ..strokeWidth = 1.1 * s
          ..isAntiAlias = false,
      );
    }
    canvas.drawLine(
      c,
      Offset(c.dx + r * math.cos(baseAngle), c.dy + r * math.sin(baseAngle)),
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.55)
        ..strokeWidth = 1.4 * s
        ..isAntiAlias = false,
    );

    for (final frac in [0.28, 0.55, 0.82, 1.0]) {
      final rr = r * frac;
      final paint = Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(
          alpha: frac == 1.0 ? 0.8 : 0.42,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = (frac == 1.0 ? 2.0 : 1.15) * s
        ..isAntiAlias = false;
      const steps = 32;
      for (var sArc = 0; sArc < steps; sArc++) {
        if (sArc.isOdd) continue;
        final a0 = baseAngle - wedgeHalf + (2 * wedgeHalf) * (sArc / steps);
        final a1 = baseAngle - wedgeHalf + (2 * wedgeHalf) * ((sArc + 1) / steps);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: rr),
          a0,
          a1 - a0,
          false,
          paint,
        );
      }
    }

    canvas.save();
    canvas.clipPath(wedgePath, doAntiAlias: true);
    final phase = sweepT % 1.0;
    final rrWave = r * phase;
    if (rrWave >= 4 * s && rrWave <= r) {
      final fade = (1.0 - phase);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rrWave),
        baseAngle - wedgeHalf,
        wedgeHalf * 2,
        false,
        Paint()
          ..color = SpeedcamRadarWidget.phosphorGlow.withValues(
            alpha: 0.25 + 0.6 * fade,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.2 + 1.4 * fade) * s
          ..isAntiAlias = false,
      );
    }
    canvas.restore(); // end wedge sweep clip

    canvas.drawCircle(c, 4 * s, Paint()..color = SpeedcamRadarWidget.phosphorGlow);
    canvas.drawCircle(c, 2 * s, Paint()..color = const Color(0xFFE8FFE8));

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
          ) *
          s;
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
      final blink = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(blinkT * math.pi * 2 * 2));
      final alpha = (baseA * blink).clamp(0.12, 1.0);
      final glowA = b.highlight ? alpha * 0.4 : alpha * 0.2;
      final fill = alienBlipFillColor(highlight: b.highlight);
      final glowColor = b.highlight
          ? SpeedcamRadarWidget.blipDanger
          : SpeedcamRadarWidget.phosphorGlow;
      canvas.drawCircle(
        p,
        rad + (b.highlight ? 2.4 : 1.4) * s,
        Paint()
          ..color = glowColor.withValues(alpha: glowA)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
      );
      canvas.drawCircle(
        p,
        b.highlight ? rad : rad * 0.85,
        Paint()..color = fill.withValues(alpha: alpha),
      );
    }

    canvas.restore(); // end CRT clip (fan/blips)

    // Glass rim (decorative; does not clip content)
    canvas.drawRRect(
      crtRRect,
      Paint()
        ..color = SpeedcamRadarWidget.phosphor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s
        ..isAntiAlias = false,
    );

    // Km + limit: LARGE bottom-left (~0.21 of min-side), overlaps fan apex /
    // left lobe (Maxim 0083 bar — enlarge Overlay/preview to classic HUD, do
    // NOT shrink HUD to Overlay-small). Stay left of center; modest L/B pad.
    if (readoutM != null) {
      final cornerPad = math.max(pad, 8.0 * s);
      final km = TextPainter(
        text: TextSpan(
          text: (readoutM! / 1000).toStringAsFixed(2),
          style: TextStyle(
            color: SpeedcamRadarWidget.phosphor,
            fontSize: kAlienCrtKmDesignFont * s,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      final limit = TextPainter(
        text: TextSpan(
          text: maxspeed != null ? '$maxspeed' : '',
          style: TextStyle(
            color: SpeedcamRadarWidget.phosphor.withValues(alpha: 0.75),
            fontSize: kAlienCrtLimitDesignFont * s,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      final stackH = km.height + (maxspeed != null ? limit.height + 2 * s : 0);
      final kmLeft = cornerPad;
      // Flush toward plate bottom so stack overlaps fan apex, not empty air.
      final kmTop = (size.height - cornerPad - stackH).clamp(0.0, size.height - stackH);
      km.paint(canvas, Offset(kmLeft, kmTop));
      if (maxspeed != null) {
        limit.paint(canvas, Offset(kmLeft, kmTop + km.height + 2 * s));
      }
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
      old.blinkT != blinkT ||
      old.blips != blips ||
      old.displayRadiusM != displayRadiusM ||
      old.readoutM != readoutM ||
      old.maxspeed != maxspeed;
}


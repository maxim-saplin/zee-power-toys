import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/car_signals.dart';

import 'drive_mode_accents.dart';

/// 0110/0112/0113 — persistent bottom-right drive-mode corner dot (settings-gated).
///
/// Shown only when [BatteryConfig.showDriveModeCornerDot] is ON and the
/// current mode is a known three-mode chip (**ECO → Comfort → Sport**). Other /
/// unknown → hide. No fade — stays while ON+known. Accents match toast (0112):
/// ECO blue / Comfort green / Sport red (no yellow).
///
/// **0113:** Sport red **pulsates** gently ([kSportPulsePeriod]); ECO /
/// Comfort stay calm (opacity + size fixed at 1.0).
class DriveModeCornerDotLayer extends HookConsumerWidget {
  const DriveModeCornerDotLayer({super.key});

  /// Logical pad from Safe Area right / bottom edges.
  static const double kEdgePad = 14;

  /// Filled-dot diameter (shrink rather than overlap battery if needed).
  static const double kDotSize = 10;

  /// Full Sport pulse cycle — gentle glanceable breathing (~0.625 Hz).
  /// Far below seizure-risk cadence; documented in tip 0113.
  static const Duration kSportPulsePeriod = Duration(milliseconds: 1600);

  /// Sport opacity floor (peak = 1.0). Calm modes stay at 1.0.
  static const double kSportPulseOpacityMin = 0.42;

  /// Sport scale floor / ceiling around 1.0 (calm modes stay at 1.0).
  static const double kSportPulseScaleMin = 0.82;
  static const double kSportPulseScaleMax = 1.08;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(batteryConfigProvider).showDriveModeCornerDot;
    if (!enabled) return const SizedBox.shrink();

    final mode = ref.watch(driveModeProvider);
    final color = driveModeCornerDotColor(mode);
    if (color == null) return const SizedBox.shrink();

    final isSport = mode == DriveMode.sport;

    // AnimationController runs only while Sport is showing (no idle timers).
    final controller = useAnimationController(duration: kSportPulsePeriod);
    useEffect(() {
      if (isSport) {
        controller.repeat();
      } else {
        controller.stop();
        controller.value = 0.0;
      }
      return null;
    }, [isSport]);

    // Subscribe so Sport rebuilds every tick; calm modes ignore the value.
    final t = useAnimation(controller);
    final intensity = isSport ? sportPulseIntensity(t) : 0.0;
    final opacity = isSport
        ? sportPulseOpacity(intensity)
        : 1.0;
    final scale = isSport ? sportPulseScale(intensity) : 1.0;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: kEdgePad, bottom: kEdgePad),
        child: Opacity(
          key: ValueKey('drive-mode-corner-dot-opacity-${mode.name}'),
          opacity: opacity,
          child: Transform.scale(
            key: ValueKey('drive-mode-corner-dot-scale-${mode.name}'),
            scale: scale,
            child: DecoratedBox(
              key: ValueKey('drive-mode-corner-dot-${mode.name}'),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: const SizedBox(width: kDotSize, height: kDotSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Persistent corner-dot accents (0112): same as toast — ECO blue / Comfort
/// green / Sport red. Returns null for other/unknown → caller hides the dot.
Color? driveModeCornerDotColor(DriveMode mode) => DriveModeAccents.known(mode);

/// Sport pulse intensity in \[0, 1\] for controller value \[t\] ∈ \[0, 1\].
///
/// Smooth sine breath: `(1 − cos(2πt)) / 2` — 0 at period start/end, 1 at
/// mid-cycle. Pure + deterministic for unit tests (same pattern as
/// [blinkOnAt]).
double sportPulseIntensity(double t) {
  final phase = t - t.floorToDouble(); // wrap to [0, 1)
  return (1.0 - math.cos(2.0 * math.pi * phase)) / 2.0;
}

/// Opacity for a given [sportPulseIntensity] — floors at
/// [DriveModeCornerDotLayer.kSportPulseOpacityMin], peaks at 1.0.
double sportPulseOpacity(double intensity) {
  final i = intensity.clamp(0.0, 1.0);
  return DriveModeCornerDotLayer.kSportPulseOpacityMin +
      (1.0 - DriveModeCornerDotLayer.kSportPulseOpacityMin) * i;
}

/// Scale for a given [sportPulseIntensity] — between
/// [DriveModeCornerDotLayer.kSportPulseScaleMin] and
/// [DriveModeCornerDotLayer.kSportPulseScaleMax].
double sportPulseScale(double intensity) {
  final i = intensity.clamp(0.0, 1.0);
  return DriveModeCornerDotLayer.kSportPulseScaleMin +
      (DriveModeCornerDotLayer.kSportPulseScaleMax -
              DriveModeCornerDotLayer.kSportPulseScaleMin) *
          i;
}

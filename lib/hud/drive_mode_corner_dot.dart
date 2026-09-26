import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/car_signals.dart';

import 'drive_mode_accents.dart';

/// 0110/0112 — persistent bottom-right drive-mode corner dot (settings-gated).
///
/// Shown only when [BatteryConfig.showDriveModeCornerDot] is ON and the
/// current mode is a known three-mode chip (**ECO → Comfort → Sport**). Other /
/// unknown → hide. No fade — stays while ON+known. Accents match toast (0112):
/// ECO blue / Comfort green / Sport red (no yellow).
class DriveModeCornerDotLayer extends ConsumerWidget {
  const DriveModeCornerDotLayer({super.key});

  /// Logical pad from Safe Area right / bottom edges.
  static const double kEdgePad = 14;

  /// Filled-dot diameter (shrink rather than overlap battery if needed).
  static const double kDotSize = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(batteryConfigProvider).showDriveModeCornerDot;
    if (!enabled) return const SizedBox.shrink();

    final mode = ref.watch(driveModeProvider);
    final color = driveModeCornerDotColor(mode);
    if (color == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: kEdgePad, bottom: kEdgePad),
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
    );
  }
}

/// Persistent corner-dot accents (0112): same as toast — ECO blue / Comfort
/// green / Sport red. Returns null for other/unknown → caller hides the dot.
Color? driveModeCornerDotColor(DriveMode mode) => DriveModeAccents.known(mode);

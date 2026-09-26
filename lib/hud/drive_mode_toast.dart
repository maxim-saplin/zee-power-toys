import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/drive_mode_toast.dart';
import '../services/car_signals.dart';
import '../services/drive_mode_mapping.dart';

import 'drive_mode_accents.dart';

/// 0104/0109 — ephemeral HUD drive-mode toast (~5 s hold, then fade).
///
/// Top-centre Safe Area — raised above the speedo cluster (0109), still clear
/// of blinkers (edges), battery, Alien radar.
class DriveModeToastLayer extends ConsumerStatefulWidget {
  const DriveModeToastLayer({super.key});

  @override
  ConsumerState<DriveModeToastLayer> createState() =>
      _DriveModeToastLayerState();
}

class _DriveModeToastLayerState extends ConsumerState<DriveModeToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  DriveModeToast? _showing;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 0,
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _sync(DriveModeToast? next) {
    if (next == null) {
      if (_showing != null) {
        _fade.reverse().whenComplete(() {
          if (mounted) setState(() => _showing = null);
        });
      }
      return;
    }
    setState(() => _showing = next);
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriveModeToast?>(driveModeToastProvider, (prev, next) {
      _sync(next);
    });
    final current = ref.watch(driveModeToastProvider);
    if (current != null && _showing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync(current);
      });
    }

    final toast = _showing;
    if (toast == null) return const SizedBox.shrink();

    final accent = driveModeToastAccent(toast.mode);
    final label = DriveModeMapping.hudLabel(toast.mode);
    if (label.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: Align(
        // 0109: raise from prior -0.55 so chrome clears the speedo on dens320.
        alignment: const Alignment(0, -0.82),
        child: DecoratedBox(
          key: const ValueKey('drive-mode-toast'),
          decoration: BoxDecoration(
            color: const Color(0xE6101218),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(toast.mode), color: accent, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  key: ValueKey('drive-mode-toast-label-$label'),
                  style: TextStyle(
                    color: const Color(0xFFF2F4F8),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    height: 1.0,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(DriveMode mode) => switch (mode) {
        DriveMode.eco => Icons.eco_outlined,
        DriveMode.comfort => Icons.directions_car_outlined,
        DriveMode.sport => Icons.speed,
        DriveMode.other => Icons.tune,
        DriveMode.unknown => Icons.tune,
      };
}

/// 0112 toast accents: ECO blue / Comfort green / Sport red; other/unknown soft grey.
/// Same palette as [driveModeCornerDotColor]. See [DriveModeAccents].
Color driveModeToastAccent(DriveMode mode) => DriveModeAccents.toast(mode);

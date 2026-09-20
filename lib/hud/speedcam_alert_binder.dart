import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/services.dart';
import '../providers/speedcam.dart';
import '../services/config_store.dart';
import '../services/speedcam_alert.dart';
import '../services/speedcam_alien_ping.dart';

/// Approach sting (0035) + Alien range ping loop (0040).
class SpeedcamAlertBinder extends HookConsumerWidget {
  const SpeedcamAlertBinder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(speedcamAlertProvider);
    final cfg = ref.watch(speedcamConfigProvider);
    final danger = ref.watch(speedcamDangerProvider);

    final arm = useMemoized(() => SpeedcamApproachArm(alert: alert), [alert]);
    final ping = useMemoized(() => SpeedcamAlienPingLoop(alert: alert), [alert]);
    arm.enabled = cfg.soundEnabled;

    useEffect(() {
      alert.setVolume(cfg.soundVolume);
      return null;
    }, [alert, cfg.soundVolume]);

    useEffect(() {
      final inside = danger?.insideApproach ?? false;
      arm.onInsideApproach(inside);
      return null;
    }, [danger?.insideApproach, danger?.cam.id, cfg.soundEnabled]);

    useEffect(() {
      ping.update(
        enabled: cfg.soundEnabled,
        alienLook: cfg.radarLook == SpeedcamRadarLook.alien,
        insideApproach: danger?.insideApproach ?? false,
        distanceM: danger?.distanceM,
      );
      return null;
    }, [
      cfg.soundEnabled,
      cfg.radarLook,
      danger?.insideApproach,
      danger?.distanceM,
      danger?.cam.id,
    ]);

    useEffect(() {
      return ping.dispose;
    }, [ping]);

    return child;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/services.dart';
import '../providers/speedcam.dart';
import '../services/config_store.dart';
import '../services/speedcam.dart';
import '../services/speedcam_alert.dart';
import '../services/speedcam_alien_ping.dart';

/// Approach sting (0035) + Alien range ping loop (0040).
///
/// Sound channel respects [SpeedcamConfig.soundMode] (0060). Alien ping and
/// Default sting share the same danger selection for sound.
class SpeedcamAlertBinder extends HookConsumerWidget {
  const SpeedcamAlertBinder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(speedcamAlertProvider);
    final cfg = ref.watch(speedcamConfigProvider);
    final danger = ref.watch(speedcamDangerProvider);
    final snap = ref.watch(speedcamSnapshotProvider);

    final arm = useMemoized(() => SpeedcamApproachArm(alert: alert), [alert]);
    final ping = useMemoized(() => SpeedcamAlienPingLoop(alert: alert), [alert]);
    final soundOn = cfg.soundMode != SpeedcamPresenceMode.off;
    arm.enabled = soundOn;

    // 0074: when YNavi alert off (or enrich off), ignore ynavi-sourced cams for sound.
    // 0092/0102: drop other-traffic cams when alertLaneCams is off (soundMode=any).
    var alertCams = (!cfg.ynaviEnrichEnabled || !cfg.ynaviAlertEnabled)
        ? snap.cams.where((c) => !c.isYnaviSourced).toList()
        : List<SpeedcamPoint>.from(snap.cams);
    alertCams = applyLaneCamAlertFilter(
      alertCams,
      alertLaneCams: cfg.alertLaneCams,
    );
    final alertDanger = resolvePresenceDanger(
      mode: cfg.soundMode,
      host: snap.host,
      cams: alertCams,
      approachRadiusM: snap.approachRadiusM > 0
          ? snap.approachRadiusM
          : cfg.dhuRangeM,
      serviceDanger: (!cfg.ynaviEnrichEnabled || !cfg.ynaviAlertEnabled) &&
              (danger?.cam.isYnaviSourced ?? false)
          ? null
          : danger,
    );

    useEffect(() {
      alert.setVolume(cfg.soundVolume);
      return null;
    }, [alert, cfg.soundVolume]);

    useEffect(() {
      final inside = alertDanger?.insideApproach ?? false;
      arm.onInsideApproach(inside);
      return null;
    }, [alertDanger?.insideApproach, alertDanger?.cam.id, cfg.soundMode, cfg.ynaviAlertEnabled, cfg.ynaviEnrichEnabled]);

    useEffect(() {
      ping.update(
        enabled: soundOn,
        alienLook: cfg.radarLook == SpeedcamRadarLook.alien,
        insideApproach: alertDanger?.insideApproach ?? false,
        distanceM: alertDanger?.distanceM,
      );
      return null;
    }, [
      cfg.soundMode,
      cfg.radarLook,
      alertDanger?.insideApproach,
      alertDanger?.distanceM,
      alertDanger?.cam.id,
    ]);

    useEffect(() {
      return ping.dispose;
    }, [ping]);

    return child;
  }
}

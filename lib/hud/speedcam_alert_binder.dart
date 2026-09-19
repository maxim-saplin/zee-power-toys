import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/services.dart';
import '../providers/speedcam.dart';
import '../services/speedcam_alert.dart';

/// Listens to pack proximity and fires the approach sting on enter (0035).
class SpeedcamAlertBinder extends HookConsumerWidget {
  const SpeedcamAlertBinder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(speedcamAlertProvider);
    final soundOn = ref.watch(speedcamConfigProvider).soundEnabled;
    final danger = ref.watch(speedcamDangerProvider);

    final arm = useMemoized(() => SpeedcamApproachArm(alert: alert), [alert]);
    arm.enabled = soundOn;

    useEffect(() {
      final inside = danger?.insideApproach ?? false;
      arm.onInsideApproach(inside);
      return null;
    }, [danger?.insideApproach, danger?.cam.id, soundOn]);

    return child;
  }
}

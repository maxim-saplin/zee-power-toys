import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';
import '../providers/config.dart';
import '../services/config_store.dart';

/// 0070/0079/0106 — Flutter surface hosted in [TYPE_APPLICATION_OVERLAY].
///
/// Alien uses the same [hudCompact] paint path as the windshield (no idle CRT,
/// transparent plate). Default keeps dhuLarge for readable text on the plate.
///
/// Body is [SizedBox.expand] so Alien [FittedBox] gets tight window constraints;
/// watches [SpeedcamConfig.overlaySizeScale] so a live slider rebuild pairs with
/// native window resize (0106).
class SpeedcamOverlayApp extends StatelessWidget {
  const SpeedcamOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      // Same pin as HudApp/DhuApp — OS font scale must not diverge Overlay type.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        child: child!,
      ),
      home: const _OverlayHome(),
    );
  }
}

class _OverlayHome extends ConsumerWidget {
  const _OverlayHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(speedcamConfigProvider);
    final look = sc.radarLook;
    final isAlien = look == SpeedcamRadarLook.alien;
    // 0106: touch scale so rebuild tracks live slider with native window resize.
    final scale = sc.overlaySizeScale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        key: ValueKey('speedcam-overlay-scale-$scale'),
        child: ColoredBox(
          color: isAlien ? Colors.transparent : const Color(0xE6101014),
          child: Padding(
            padding: EdgeInsets.all(isAlien ? 0 : 8),
            child: SpeedcamRadarWidget(
              key: const ValueKey('speedcam-system-overlay-radar'),
              variant: isAlien
                  ? SpeedcamRadarVariant.hudCompact
                  : SpeedcamRadarVariant.dhuLarge,
              alwaysShow: false,
            ),
          ),
        ),
      ),
    );
  }
}

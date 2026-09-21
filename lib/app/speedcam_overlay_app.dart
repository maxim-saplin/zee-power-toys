import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';
import '../providers/config.dart';
import '../services/config_store.dart';

/// 0070/0079 — Flutter surface hosted in [TYPE_APPLICATION_OVERLAY].
///
/// Alien uses the same [hudCompact] paint path as the windshield (no idle CRT,
/// transparent plate). Default keeps dhuLarge for readable text on the plate.
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
      home: const _OverlayHome(),
    );
  }
}

class _OverlayHome extends ConsumerWidget {
  const _OverlayHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(speedcamConfigProvider).radarLook;
    final isAlien = look == SpeedcamRadarLook.alien;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
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
    );
  }
}

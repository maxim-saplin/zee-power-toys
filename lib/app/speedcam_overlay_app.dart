import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';

/// 0070 — Flutter surface hosted in [TYPE_APPLICATION_OVERLAY].
///
/// Same [SpeedcamRadarWidget] (Alien|Default) as HUD / DHU settings preview.
/// Snapshot + config arrive via zee/hub relay (same path as HUD).
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
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: Color(0xE6101014),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: SpeedcamRadarWidget(
            key: ValueKey('speedcam-system-overlay-radar'),
            variant: SpeedcamRadarVariant.dhuLarge,
            alwaysShow: true,
          ),
        ),
      ),
    );
  }
}

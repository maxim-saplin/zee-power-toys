import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import '../hud/hud_root.dart';
import '../hud/speedcam_alert_binder.dart';
import '../theme/app_theme.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey hudShotKey = GlobalKey();

/// HUD surface app.
///
/// The backdrop is platform-conditional:
/// - **Android (T2/T3):** transparent, so the native `MinimapView` under-layer
///   composites through the `FlutterTextureView(isOpaque=false)` (Block 0009,
///   ADR 0001 Minimap exception).
/// - **Desktop (T1):** pure black — there is no native under-layer, and the HUD
///   is emissive (black = no projector light = transparent on the windshield).
class HudApp extends StatelessWidget {
  const HudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // The HUD shares the DHU's dark theme so any Material defaults (text
      // colour, etc.) stay dark — but the emissive rule still owns the
      // backdrop: the scaffold below is black/transparent, never light.
      theme: AppTheme.dhu,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dhu,
      // Clamp text scaling so OS accessibility settings can't inflate emissive
      // marks beyond the Safe Area (the HUD has fixed optics).
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        child: child!,
      ),
      home: RepaintBoundary(key: hudShotKey, child: const _HudScreen()),
    );
  }
}

/// True on Android, where the HUD composites over a native Minimap surface.
bool get _compositesOverNative =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class _HudScreen extends StatelessWidget {
  const _HudScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _compositesOverNative ? Colors.transparent : Colors.black,
      body: const SpeedcamAlertBinder(child: HudRoot()),
    );
  }
}



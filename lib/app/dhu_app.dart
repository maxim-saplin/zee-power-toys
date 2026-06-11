import 'package:flutter/material.dart';

import '../screens/hud_settings_screen.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey dhuShotKey = GlobalKey();

/// DHU surface app — shows the HUD settings screen with live preview.
class DhuApp extends StatelessWidget {
  const DhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: dhuShotKey, child: const HudSettingsScreen()),
    );
  }
}


import 'package:flutter/material.dart';

import '../hud/hud_root.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey hudShotKey = GlobalKey();

/// HUD surface app — black background, real HudRoot content.
/// No Material theming: HUD is emissive-on-black; Scaffold is used only to
/// pin a deterministic background colour so RepaintBoundary captures correctly.
class HudApp extends StatelessWidget {
  const HudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: hudShotKey, child: const _HudScreen()),
    );
  }
}

class _HudScreen extends StatelessWidget {
  const _HudScreen();

  @override
  Widget build(BuildContext context) {
    // Scaffold only for the black background guarantee; HudRoot fills it.
    // showSafeAreaBorder is false on the real HUD surface — the border is only
    // useful in the DHU preview.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: HudRoot(),
    );
  }
}


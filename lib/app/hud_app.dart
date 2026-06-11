import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey hudShotKey = GlobalKey();

/// HUD surface app — ugly on purpose; no theming yet.
/// Renders a solid yellow box when hudBoxOn is true, nothing when false.
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

class _HudScreen extends ConsumerWidget {
  const _HudScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hudBoxOn = ref.watch(hudBoxOnProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: hudBoxOn
            ? Container(
                width: 200,
                height: 200,
                color: const Color(0xFFFFEB3B), // yellow — clearly visible
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

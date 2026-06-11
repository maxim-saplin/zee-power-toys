import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../widgets/hud_preview.dart';

/// DHU screen: HUD layout settings + live preview.
///
/// Shows the [HudPreview] (same widget tree as the real HUD) over a grey
/// background so any Safe-Area or layout change is immediately visible.
/// Provides a Safe-Area inset slider and the debug hudBox toggle.
class HudSettingsScreen extends ConsumerWidget {
  const HudSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaProvider);
    final hudBoxOn = ref.watch(hudBoxOnProvider);
    final store = ref.read(configStoreProvider);

    // Uniform inset: use the average of left/top insets as the slider value.
    // Adjusting the slider applies a symmetric inset to all four edges.
    // This is the single-knob convenience control; T3 calibration uses
    // individual edge values via setConfig/dumpState.
    final currentInset = (safeArea.left + safeArea.top) / 2;

    return Scaffold(
      appBar: AppBar(title: const Text('HUD Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Live HUD preview — the SAME HudRoot, scaled to fit.
            const HudPreview(),

            const SizedBox(height: 24),

            // Safe Area inset slider.
            const Text(
              'Safe Area inset',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Text('0%'),
                Expanded(
                  child: Slider(
                    key: const ValueKey('safe-area-inset-slider'),
                    min: 0.0,
                    max: 0.25,
                    divisions: 50,
                    value: currentInset.clamp(0.0, 0.25),
                    label: '${(currentInset * 100).toStringAsFixed(1)}%',
                    onChanged: (v) {
                      // Symmetric inset: all four edges pull in by v.
                      // right/bottom shrink from the opposite edge: 1 - v.
                      final next = safeArea.copyWith(
                        left: v,
                        top: v,
                        right: 1.0 - v,
                        bottom: 1.0 - v,
                      );
                      store.setConfig(store.value.copyWith(safeArea: next));
                    },
                  ),
                ),
                const Text('25%'),
              ],
            ),

            const SizedBox(height: 16),

            // Debug: hudBox toggle (retained from Block 0001 skeleton).
            Row(
              children: <Widget>[
                const Text('Debug HUD box'),
                const SizedBox(width: 12),
                Switch(
                  key: const ValueKey('dhu-toggle'),
                  value: hudBoxOn,
                  onChanged: (_) => store.setConfig(
                    store.value.copyWith(hudBoxOn: !hudBoxOn),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Current Safe Area values — useful during T3 calibration.
            _SafeAreaReadout(safeArea: safeArea),
          ],
        ),
      ),
    );
  }
}

class _SafeAreaReadout extends StatelessWidget {
  const _SafeAreaReadout({required this.safeArea});

  final HudSafeArea safeArea;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Safe Area (fractions)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text('left:   ${safeArea.left.toStringAsFixed(4)}'),
          Text('top:    ${safeArea.top.toStringAsFixed(4)}'),
          Text('right:  ${safeArea.right.toStringAsFixed(4)}'),
          Text('bottom: ${safeArea.bottom.toStringAsFixed(4)}'),
        ],
      ),
    );
  }
}

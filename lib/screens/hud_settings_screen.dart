import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../widgets/hud_preview.dart';

/// DHU screen: HUD layout settings + live preview.
///
/// Shows the [HudPreview] (same widget tree as the real HUD) over a grey
/// background so any Safe-Area or layout change is immediately visible.
/// Provides a Safe-Area inset slider, the debug hudBox toggle, a
/// Blinker section (shape selector + size slider + position controls),
/// and a Battery section (show/hide toggles + size slider).
class HudSettingsScreen extends ConsumerWidget {
  const HudSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final safeArea = ref.watch(safeAreaProvider);
    final hudBoxOn = ref.watch(hudBoxOnProvider);
    final blinkerCfg = ref.watch(blinkerConfigProvider);
    final batteryCfg = ref.watch(batteryConfigProvider);
    final store = ref.read(configStoreProvider);

    // Uniform inset: use the average of left/top insets as the slider value.
    // Adjusting the slider applies a symmetric inset to all four edges.
    // This is the single-knob convenience control; T3 calibration uses
    // individual edge values via setConfig/dumpState.
    final currentInset = (safeArea.left + safeArea.top) / 2;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hudSettingsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Live HUD preview — the SAME HudRoot, scaled to fit.
            const HudPreview(),

            const SizedBox(height: 24),

            // Safe Area inset slider.
            Text(
              l10n.safeAreaInset,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                Text(l10n.debugHudBox),
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

            // ----------------------------------------------------------------
            // Blinker section
            // ----------------------------------------------------------------
            Text(
              l10n.blinkerSection,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Shape selector — three segments.
            Text(l10n.blinkerShape),
            const SizedBox(height: 8),
            SegmentedButton<BlinkerShape>(
              segments: <ButtonSegment<BlinkerShape>>[
                ButtonSegment(
                  value: BlinkerShape.dots,
                  label: Text(l10n.blinkerShapeDots),
                  icon: const Icon(Icons.circle_outlined),
                ),
                ButtonSegment(
                  value: BlinkerShape.arrows,
                  label: Text(l10n.blinkerShapeArrows),
                  icon: const Icon(Icons.arrow_forward),
                ),
                ButtonSegment(
                  value: BlinkerShape.smiley,
                  label: Text(l10n.blinkerShapeSmiley),
                  icon: const Icon(Icons.sentiment_satisfied_alt),
                ),
              ],
              selected: <BlinkerShape>{blinkerCfg.shape},
              onSelectionChanged: (Set<BlinkerShape> sel) {
                if (sel.isEmpty) return;
                store.setConfig(
                  store.value.copyWith(
                    blinker: blinkerCfg.copyWith(shape: sel.first),
                  ),
                );
              },
            ),
            // ValueKey hooks for agent-driven tap (one per segment).
            Opacity(
              opacity: 0,
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    key: const ValueKey('blinker-shape-dots'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        blinker: blinkerCfg.copyWith(shape: BlinkerShape.dots),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                  GestureDetector(
                    key: const ValueKey('blinker-shape-arrows'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        blinker: blinkerCfg.copyWith(shape: BlinkerShape.arrows),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                  GestureDetector(
                    key: const ValueKey('blinker-shape-smiley'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        blinker: blinkerCfg.copyWith(shape: BlinkerShape.smiley),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Size slider.
            Text(l10n.blinkerSize),
            Row(
              children: <Widget>[
                const Text('0.5×'),
                Expanded(
                  child: Slider(
                    key: const ValueKey('blinker-size'),
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    value: blinkerCfg.sizeScale.clamp(0.5, 2.0),
                    label: '${blinkerCfg.sizeScale.toStringAsFixed(2)}×',
                    onChanged: (v) {
                      store.setConfig(
                        store.value.copyWith(
                          blinker: blinkerCfg.copyWith(sizeScale: v),
                        ),
                      );
                    },
                  ),
                ),
                const Text('2×'),
              ],
            ),

            const SizedBox(height: 16),

            // Vertical position slider.
            Text(l10n.blinkerVerticalPosition),
            Row(
              children: <Widget>[
                Text(l10n.positionTop),
                Expanded(
                  child: Slider(
                    key: const ValueKey('blinker-vert'),
                    min: 0.1,
                    max: 0.9,
                    divisions: 16,
                    value: blinkerCfg.vertFrac.clamp(0.1, 0.9),
                    label: '${(blinkerCfg.vertFrac * 100).toStringAsFixed(0)}%',
                    onChanged: (v) {
                      store.setConfig(
                        store.value.copyWith(
                          blinker: blinkerCfg.copyWith(vertFrac: v),
                        ),
                      );
                    },
                  ),
                ),
                Text(l10n.positionBottom),
              ],
            ),

            // Side padding slider.
            Text(l10n.blinkerSidePadding),
            Row(
              children: <Widget>[
                Text(l10n.positionEdge),
                Expanded(
                  child: Slider(
                    key: const ValueKey('blinker-side-pad'),
                    min: 0.0,
                    max: 0.20,
                    divisions: 20,
                    value: blinkerCfg.sidePadFrac.clamp(0.0, 0.20),
                    label: '${(blinkerCfg.sidePadFrac * 100).toStringAsFixed(0)}%',
                    onChanged: (v) {
                      store.setConfig(
                        store.value.copyWith(
                          blinker: blinkerCfg.copyWith(sidePadFrac: v),
                        ),
                      );
                    },
                  ),
                ),
                const Text('20%'),
              ],
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Battery section
            // ----------------------------------------------------------------
            Text(
              l10n.batterySection,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Show battery toggle.
            Row(
              children: <Widget>[
                Expanded(child: Text(l10n.showBattery)),
                Switch(
                  key: const ValueKey('battery-show-battery'),
                  value: batteryCfg.showBattery,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showBattery: v),
                    ),
                  ),
                ),
              ],
            ),

            // Show temperature toggle.
            Row(
              children: <Widget>[
                Expanded(child: Text(l10n.showTemp)),
                Switch(
                  key: const ValueKey('battery-show-temp'),
                  value: batteryCfg.showTemp,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showTemp: v),
                    ),
                  ),
                ),
              ],
            ),

            // Show charging stats toggle.
            Row(
              children: <Widget>[
                Expanded(child: Text(l10n.showChargingStats)),
                Switch(
                  key: const ValueKey('battery-show-charging'),
                  value: batteryCfg.showChargingStats,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showChargingStats: v),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Battery size slider.
            Text(l10n.blinkerSize),
            Row(
              children: <Widget>[
                const Text('0.5×'),
                Expanded(
                  child: Slider(
                    key: const ValueKey('battery-size'),
                    min: 0.5,
                    max: 2.5,
                    divisions: 40,
                    value: batteryCfg.sizeScale.clamp(0.5, 2.5),
                    label: '${batteryCfg.sizeScale.toStringAsFixed(2)}×',
                    onChanged: (v) {
                      store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(sizeScale: v),
                        ),
                      );
                    },
                  ),
                ),
                const Text('2.5×'),
              ],
            ),

            const SizedBox(height: 24),

            // Current Safe Area values — useful during T3 calibration.
            _SafeAreaReadout(safeArea: safeArea, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _SafeAreaReadout extends StatelessWidget {
  const _SafeAreaReadout({required this.safeArea, required this.l10n});

  final HudSafeArea safeArea;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.safeAreaSection,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

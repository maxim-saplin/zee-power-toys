import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../theme/app_theme.dart';
import '../widgets/hud_preview.dart';
import '../widgets/settings_layout.dart';

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
      body: Column(
        children: <Widget>[
          // ─── Sticky preview ──────────────────────────────────────────────
          // Capped at 200 logical dp so the blinker / battery / Safe-Area
          // controls below are always reachable without scrolling the preview
          // out of sight.  The preview stays live while any control is edited.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.button),
              child: const HudPreview(),
            ),
          ),

          // ─── Scrollable controls ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: <Widget>[
                // ----------------------------------------------------------------
                // Layout section: Safe Area inset + debug toggle
                // ----------------------------------------------------------------
                SettingsSection(
                  title: l10n.sectionHud,
                  children: <Widget>[
                    SettingsSlider(
                      label: l10n.safeAreaInset,
                      valueLabel: '${(currentInset * 100).toStringAsFixed(1)}%',
                      minLabel: '0%',
                      maxLabel: '25%',
                      sliderKey: const ValueKey('safe-area-inset-slider'),
                      min: 0.0,
                      max: 0.25,
                      divisions: 50,
                      value: currentInset.clamp(0.0, 0.25),
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
                    const SizedBox(height: Insets.xs),
                    // Debug: hudBox toggle (retained from Block 0001 skeleton).
                    SettingsToggleRow(
                      label: l10n.debugHudBox,
                      control: Switch(
                        key: const ValueKey('dhu-toggle'),
                        value: hudBoxOn,
                        onChanged: (_) => store.setConfig(
                          store.value.copyWith(hudBoxOn: !hudBoxOn),
                        ),
                      ),
                    ),
                  ],
                ),

          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Blinker section
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.blinkerSection,
            children: <Widget>[
              Text(
                l10n.blinkerShape,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.sm),
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
                          blinker: blinkerCfg.copyWith(
                            shape: BlinkerShape.dots,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('blinker-shape-arrows'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          blinker: blinkerCfg.copyWith(
                            shape: BlinkerShape.arrows,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('blinker-shape-smiley'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          blinker: blinkerCfg.copyWith(
                            shape: BlinkerShape.smiley,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.lg),
              SettingsSlider(
                label: l10n.blinkerSize,
                valueLabel: '${blinkerCfg.sizeScale.toStringAsFixed(2)}×',
                minLabel: '0.5×',
                maxLabel: '2×',
                sliderKey: const ValueKey('blinker-size'),
                min: 0.5,
                max: 2.0,
                divisions: 30,
                value: blinkerCfg.sizeScale.clamp(0.5, 2.0),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      blinker: blinkerCfg.copyWith(sizeScale: v),
                    ),
                  );
                },
              ),

              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: l10n.blinkerVerticalPosition,
                valueLabel:
                    '${(blinkerCfg.vertFrac * 100).toStringAsFixed(0)}%',
                minLabel: l10n.positionTop,
                maxLabel: l10n.positionBottom,
                sliderKey: const ValueKey('blinker-vert'),
                min: 0.1,
                max: 0.9,
                divisions: 16,
                value: blinkerCfg.vertFrac.clamp(0.1, 0.9),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      blinker: blinkerCfg.copyWith(vertFrac: v),
                    ),
                  );
                },
              ),

              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: l10n.blinkerSidePadding,
                valueLabel:
                    '${(blinkerCfg.sidePadFrac * 100).toStringAsFixed(0)}%',
                minLabel: l10n.positionEdge,
                maxLabel: '20%',
                sliderKey: const ValueKey('blinker-side-pad'),
                min: 0.0,
                max: 0.20,
                divisions: 20,
                value: blinkerCfg.sidePadFrac.clamp(0.0, 0.20),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      blinker: blinkerCfg.copyWith(sidePadFrac: v),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Battery section
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.batterySection,
            children: <Widget>[
              SettingsToggleRow(
                label: l10n.showBattery,
                control: Switch(
                  key: const ValueKey('battery-show-battery'),
                  value: batteryCfg.showBattery,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showBattery: v),
                    ),
                  ),
                ),
              ),
              SettingsToggleRow(
                label: l10n.showTemp,
                control: Switch(
                  key: const ValueKey('battery-show-temp'),
                  value: batteryCfg.showTemp,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showTemp: v),
                    ),
                  ),
                ),
              ),
              SettingsToggleRow(
                label: l10n.showChargingStats,
                control: Switch(
                  key: const ValueKey('battery-show-charging'),
                  value: batteryCfg.showChargingStats,
                  onChanged: (v) => store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(showChargingStats: v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: l10n.blinkerSize,
                valueLabel: '${batteryCfg.sizeScale.toStringAsFixed(2)}×',
                minLabel: '0.5×',
                maxLabel: '2.5×',
                sliderKey: const ValueKey('battery-size'),
                min: 0.5,
                max: 2.5,
                divisions: 40,
                value: batteryCfg.sizeScale.clamp(0.5, 2.5),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(sizeScale: v),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // Current Safe Area values — useful during T3 calibration.
          SettingsSection(
            title: l10n.safeAreaSection,
            children: <Widget>[_SafeAreaReadout(safeArea: safeArea)],
          ),
        ],
      ),
    ), // end Expanded
    ], // end Column children
  ), // end Column
);
  }
}

class _SafeAreaReadout extends StatelessWidget {
  const _SafeAreaReadout({required this.safeArea});

  final HudSafeArea safeArea;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: Theme.of(context).colorScheme.onSurface,
    );
    return DefaultTextStyle(
      style: style ?? const TextStyle(fontFamily: 'monospace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('left:   ${safeArea.left.toStringAsFixed(4)}'),
          Text('top:    ${safeArea.top.toStringAsFixed(4)}'),
          Text('right:  ${safeArea.right.toStringAsFixed(4)}'),
          Text('bottom: ${safeArea.bottom.toStringAsFixed(4)}'),
        ],
      ),
    );
  }
}

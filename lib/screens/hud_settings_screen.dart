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
/// Defaults to the Safe-Area letterbox view (what the driver actually sees);
/// the "Full display" toggle switches to the secondary full-backing-display
/// debug view with the Safe Area outlined. Provides a Safe-Area inset slider,
/// the debug hudBox toggle, a Blinker section (shape selector + size slider +
/// position controls), and a Battery section (show/hide toggles + size
/// slider).
class HudSettingsScreen extends ConsumerStatefulWidget {
  const HudSettingsScreen({super.key});

  @override
  ConsumerState<HudSettingsScreen> createState() => _HudSettingsScreenState();
}

class _HudSettingsScreenState extends ConsumerState<HudSettingsScreen> {
  // Preview-only debug toggle, not persisted config: switches the sticky
  // preview between the default Safe-Area letterbox and the secondary
  // full-backing-display debug view.
  bool _fullDisplay = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeArea = ref.watch(safeAreaProvider);
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
              child: HudPreview(
                mode: _fullDisplay
                    ? HudPreviewMode.fullDisplay
                    : HudPreviewMode.letterbox,
              ),
            ),
          ),

          // ─── Scrollable controls ─────────────────────────────────────────
          Expanded(
            child: ListView(
              // Keep battery/blinker agent keys built below the fold for FL.
              // ignore: deprecated_member_use
              cacheExtent: 4000,
              padding: const EdgeInsets.all(Insets.lg),
              children: <Widget>[
                // ----------------------------------------------------------------
                // Layout section: Safe Area inset + debug toggle
                // ----------------------------------------------------------------
                SettingsSection(
                  title: l10n.sectionHud,
                  children: <Widget>[
                    SettingsToggleRow(
                      label: l10n.hudFullDisplayToggle,
                      subtitle: Text(
                        l10n.hudFullDisplayToggleSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      control: Switch(
                        key: const ValueKey('hud-full-display-toggle'),
                        value: _fullDisplay,
                        onChanged: (v) => setState(() => _fullDisplay = v),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
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
                maxLabel: '35%',
                sliderKey: const ValueKey('blinker-side-pad'),
                min: 0.0,
                max: 0.35,
                divisions: 35,
                value: blinkerCfg.sidePadFrac.clamp(0.0, 0.35),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      blinker: blinkerCfg.copyWith(sidePadFrac: v),
                    ),
                  );
                },
              ),

              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: 'Horizontal bias',
                valueLabel:
                    '${(blinkerCfg.horizBiasFrac * 100).toStringAsFixed(0)}%',
                minLabel: '←',
                maxLabel: '→',
                sliderKey: const ValueKey('blinker-horiz-bias'),
                min: -0.25,
                max: 0.25,
                divisions: 50,
                value: blinkerCfg.horizBiasFrac.clamp(-0.25, 0.25),
                onChanged: (v) {
                  store.setConfig(
                    store.value.copyWith(
                      blinker: blinkerCfg.copyWith(horizBiasFrac: v),
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
              const SizedBox(height: Insets.md),
              Text(
                l10n.batteryContentMode,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.sm),
              SegmentedButton<BatteryContentMode>(
                segments: <ButtonSegment<BatteryContentMode>>[
                  ButtonSegment(
                    value: BatteryContentMode.both,
                    label: Text(l10n.batteryContentBoth),
                    icon: const Icon(Icons.battery_full),
                  ),
                  ButtonSegment(
                    value: BatteryContentMode.iconOnly,
                    label: Text(l10n.batteryContentIconOnly),
                    icon: const Icon(Icons.battery_std),
                  ),
                  ButtonSegment(
                    value: BatteryContentMode.textOnly,
                    label: Text(l10n.batteryContentTextOnly),
                    icon: const Icon(Icons.text_fields),
                  ),
                ],
                selected: <BatteryContentMode>{batteryCfg.contentMode},
                onSelectionChanged: (Set<BatteryContentMode> sel) {
                  if (sel.isEmpty) return;
                  store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(contentMode: sel.first),
                    ),
                  );
                },
              ),
              Opacity(
                opacity: 0,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey('battery-content-both'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            contentMode: BatteryContentMode.both,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('battery-content-icon-only'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            contentMode: BatteryContentMode.iconOnly,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('battery-content-text-only'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            contentMode: BatteryContentMode.textOnly,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                l10n.batteryStyle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.sm),
              SegmentedButton<BatteryStyle>(
                segments: <ButtonSegment<BatteryStyle>>[
                  ButtonSegment(
                    value: BatteryStyle.outline,
                    label: Text(l10n.batteryStyleOutline),
                    icon: const Icon(Icons.battery_saver_outlined),
                  ),
                  ButtonSegment(
                    value: BatteryStyle.filled,
                    label: Text(l10n.batteryStyleFilled),
                    icon: const Icon(Icons.view_column),
                  ),
                  ButtonSegment(
                    value: BatteryStyle.pctInside,
                    label: Text(l10n.batteryStylePctInside),
                    icon: const Icon(Icons.pin),
                  ),
                ],
                selected: <BatteryStyle>{batteryCfg.style},
                onSelectionChanged: (Set<BatteryStyle> sel) {
                  if (sel.isEmpty) return;
                  store.setConfig(
                    store.value.copyWith(
                      battery: batteryCfg.copyWith(style: sel.first),
                    ),
                  );
                },
              ),
              Opacity(
                opacity: 0,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey('battery-style-outline'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            style: BatteryStyle.outline,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('battery-style-filled'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            style: BatteryStyle.filled,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('battery-style-pct-inside'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          battery: batteryCfg.copyWith(
                            style: BatteryStyle.pctInside,
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ],
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
                label: l10n.batterySize,
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

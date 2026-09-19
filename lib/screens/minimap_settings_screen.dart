import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../services/minimap_viewport.dart' show hudPresetSizeFraction;
import '../theme/app_theme.dart';
import '../widgets/settings_layout.dart';

/// DHU screen: YNavi minimap configuration.
///
/// Enable toggle — disabled when ynaviAvailableProvider is false (no compatible
/// mod detected), shown with a localized hint.
/// Size: compact/balanced/large presets plus an always-visible Size slider
/// ([MinimapConfig.sizeFraction]). The old Advanced ExpansionTile was removed —
/// it locked presets when expanded and cost the same space as the slider itself.
/// Look section: colour preset / brightness (threshold) / contrast — the
/// three [MinimapLooks] knobs pushed to the native ColorMatrix filter via
/// `host.setParams` in `_applyMinimapConfig` (main.dart).
///
/// There is no Theme section any more — see [MinimapConfig]'s doc comment
/// (config_store.dart) for why `themeFollow` was deleted rather than wired.
///
/// All changes go through store.setConfig → persisted via SharedPrefsConfigStore
/// → relayed to HUD isolate via the existing change-stream listener.
class MinimapSettingsScreen extends ConsumerWidget {
  const MinimapSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(configStoreProvider);
    final cfg = ref.watch(minimapConfigProvider);
    // FutureProvider: show a loading indicator while the async check runs.
    // On T1 the fake is synchronous so this resolves in the same frame.
    final ynaviAsync = ref.watch(ynaviAvailableProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.minimapTitle)),
      body: ynaviAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _buildBody(context, l10n, store, cfg, ynaviAvailable: false),
        data: (available) =>
            _buildBody(context, l10n, store, cfg, ynaviAvailable: available),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    dynamic store,
    MinimapConfig cfg, {
    required bool ynaviAvailable,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: <Widget>[
        // ----------------------------------------------------------------
        // Enable toggle (gated by YNavi availability)
        // ----------------------------------------------------------------
        SettingsSection(
          children: <Widget>[
            SettingsToggleRow(
              label: l10n.minimapEnable,
              subtitle: ynaviAvailable
                  ? null
                  : Text(
                      l10n.minimapYnaviUnavailableHint,
                      key: const ValueKey('minimap-ynavi-hint'),
                      style: theme.textTheme.bodySmall,
                    ),
              control: Switch(
                key: const ValueKey('minimap-enable-toggle'),
                // Disabled (greyed out) when YNavi mod is absent.
                value: ynaviAvailable && cfg.enabled,
                onChanged: ynaviAvailable
                    ? (v) {
                        store.setConfig(
                          store.value.copyWith(
                            minimap: cfg.copyWith(enabled: v),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),

        const SizedBox(height: Insets.xl),

        // ----------------------------------------------------------------
        // Size: Compact/Balanced/Large + inline Size slider (no Advanced lock)
        // ----------------------------------------------------------------
        SettingsSection(
          title: l10n.minimapSection,
          children: <Widget>[
            Text(l10n.minimapPreset, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Insets.sm),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment(
                  value: 'compact',
                  label: Text(l10n.minimapPresetCompact),
                ),
                ButtonSegment(
                  value: 'balanced',
                  label: Text(l10n.minimapPresetBalanced),
                ),
                ButtonSegment(
                  value: 'large',
                  label: Text(l10n.minimapPresetLarge),
                ),
              ],
              selected: <String>{cfg.preset},
              onSelectionChanged: (Set<String> sel) {
                if (sel.isEmpty) return;
                store.setConfig(
                  store.value.copyWith(
                    minimap: _withPreset(cfg, sel.first),
                  ),
                );
              },
            ),
            // Invisible GestureDetector hooks so agent tapByKey works on T1.
            Opacity(
              opacity: 0,
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    key: const ValueKey('minimap-preset-compact'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        minimap: _withPreset(cfg, 'compact'),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                  GestureDetector(
                    key: const ValueKey('minimap-preset-balanced'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        minimap: _withPreset(cfg, 'balanced'),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                  GestureDetector(
                    key: const ValueKey('minimap-preset-large'),
                    onTap: () => store.setConfig(
                      store.value.copyWith(
                        minimap: _withPreset(cfg, 'large'),
                      ),
                    ),
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            Builder(
              builder: (context) {
                final sizeFraction =
                    cfg.sizeFraction ?? hudPresetSizeFraction(cfg.preset);
                return SettingsSlider(
                  label: l10n.minimapSize,
                  valueLabel: '${(sizeFraction * 100).round()}%',
                  minLabel: '30%',
                  maxLabel: '100%',
                  sliderKey: const ValueKey('minimap-size-slider'),
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  value: sizeFraction.clamp(0.3, 1.0),
                  onChanged: (v) {
                    store.setConfig(
                      store.value.copyWith(
                        minimap: cfg.copyWith(advanced: false, sizeFraction: v),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),

        const SizedBox(height: Insets.xl),

        // ----------------------------------------------------------------
        // Look: colour preset / brightness / contrast — the three native
        // ColorMatrix knobs (MinimapLooks) wired all the way to
        // host.setParams in _applyMinimapConfig (main.dart). Everything else
        // MinimapParams accepts (saturation, native brightness, invert,
        // huePass, hueAngle, bufScale, dpiScale) stays ext.zee.minimap-only —
        // see MinimapLooks' doc comment (config_store.dart).
        // ----------------------------------------------------------------
        SettingsSection(
          title: l10n.minimapLookSection,
          children: <Widget>[
            Text(l10n.minimapLookPreset, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Insets.sm),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment(
                  value: 'green-yellow',
                  label: Text(l10n.minimapLookPresetGreenYellow),
                ),
                ButtonSegment(
                  value: 'white',
                  label: Text(l10n.minimapLookPresetWhite),
                ),
                ButtonSegment(
                  value: 'amber',
                  label: Text(l10n.minimapLookPresetAmber),
                ),
                ButtonSegment(
                  value: 'cyan',
                  label: Text(l10n.minimapLookPresetCyan),
                ),
              ],
              selected: <String>{cfg.looks.colorPreset},
              onSelectionChanged: (Set<String> sel) {
                if (sel.isEmpty) return;
                store.setConfig(
                  store.value.copyWith(
                    minimap: cfg.copyWith(
                      looks: cfg.looks.copyWith(colorPreset: sel.first),
                    ),
                  ),
                );
              },
            ),
            // Invisible GestureDetector hooks so agent tapByKey works on T1.
            Opacity(
              opacity: 0,
              child: Row(
                children: <Widget>[
                  for (final p in const <String>[
                    'green-yellow',
                    'white',
                    'amber',
                    'cyan',
                  ])
                    GestureDetector(
                      key: ValueKey('minimap-look-$p'),
                      onTap: () => store.setConfig(
                        store.value.copyWith(
                          minimap: cfg.copyWith(
                            looks: cfg.looks.copyWith(colorPreset: p),
                          ),
                        ),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            SettingsSlider(
              label: l10n.minimapLookBrightness,
              valueLabel: cfg.looks.threshold.round().toString(),
              minLabel: '100',
              maxLabel: '220',
              sliderKey: const ValueKey('minimap-look-brightness-slider'),
              min: 100,
              max: 220,
              divisions: 24,
              value: cfg.looks.threshold.clamp(100, 220),
              onChanged: (v) {
                store.setConfig(
                  store.value.copyWith(
                    minimap: cfg.copyWith(
                      looks: cfg.looks.copyWith(threshold: v),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: Insets.md),
            SettingsSlider(
              label: l10n.minimapLookContrast,
              valueLabel: cfg.looks.contrast.toStringAsFixed(1),
              minLabel: '1.0',
              maxLabel: '6.0',
              sliderKey: const ValueKey('minimap-look-contrast-slider'),
              min: 1.0,
              max: 6.0,
              divisions: 10,
              value: cfg.looks.contrast.clamp(1.0, 6.0),
              onChanged: (v) {
                store.setConfig(
                  store.value.copyWith(
                    minimap: cfg.copyWith(
                      looks: cfg.looks.copyWith(contrast: v),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Returns [cfg] with [preset] applied as both the size-preset name AND its
/// corresponding [MinimapConfig.sizeFraction] — presets are shortcuts for the
/// Size slider (Task 2), so picking one keeps the slider's value in sync
/// with the preset actually applied, rather than leaving a stale manual
/// value behind that would silently win the next time advanced mode reads
/// [MinimapConfig.resolvedSizeFraction].
MinimapConfig _withPreset(MinimapConfig cfg, String preset) =>
    cfg.copyWith(
      preset: preset,
      advanced: false,
      sizeFraction: hudPresetSizeFraction(preset),
    );

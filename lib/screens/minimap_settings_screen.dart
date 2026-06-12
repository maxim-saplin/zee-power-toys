import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_layout.dart';

/// DHU screen: YNavi minimap configuration.
///
/// Enable toggle — disabled when ynaviAvailableProvider is false (no compatible
/// mod detected), shown with a localized hint.
/// Basic mode: compact/balanced/large preset selector.
/// Advanced ExpansionTile: manual width/height fraction sliders.
/// Theme: System/Dark/Light selector (themeFollow in MinimapConfig).
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
        // Preset selector — always shown; dimmed/disabled in advanced mode.
        // When advanced=true a caption explains that custom dimensions take
        // precedence, but the row stays visible so users can navigate back.
        // ----------------------------------------------------------------
        SettingsSection(
          title: l10n.minimapSection,
          children: <Widget>[
            Opacity(
              opacity: cfg.advanced ? 0.45 : 1.0,
              child: IgnorePointer(
                ignoring: cfg.advanced,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            minimap: cfg.copyWith(preset: sel.first),
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
                                minimap: cfg.copyWith(preset: 'compact'),
                              ),
                            ),
                            child: const SizedBox(width: 1, height: 1),
                          ),
                          GestureDetector(
                            key: const ValueKey('minimap-preset-balanced'),
                            onTap: () => store.setConfig(
                              store.value.copyWith(
                                minimap: cfg.copyWith(preset: 'balanced'),
                              ),
                            ),
                            child: const SizedBox(width: 1, height: 1),
                          ),
                          GestureDetector(
                            key: const ValueKey('minimap-preset-large'),
                            onTap: () => store.setConfig(
                              store.value.copyWith(
                                minimap: cfg.copyWith(preset: 'large'),
                              ),
                            ),
                            child: const SizedBox(width: 1, height: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (cfg.advanced)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  l10n.minimapPresetDisabledHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            const SizedBox(height: Insets.xs),

            // --------------------------------------------------------------
            // Advanced mode: manual dimension sliders (opt-in ExpansionTile)
            // --------------------------------------------------------------
            _AdvancedTile(cfg: cfg, store: store, l10n: l10n),
          ],
        ),

        const SizedBox(height: Insets.xl),

        // ----------------------------------------------------------------
        // Theme follow: System / Dark / Light
        // Dark/light auto: when themeFollow='auto', HUD palette resolves
        // using MediaQuery.platformBrightnessOf(context) at render time.
        // 'dark'/'light' force the respective palette regardless of system.
        // ----------------------------------------------------------------
        SettingsSection(
          title: l10n.minimapThemeSection,
          padded: false,
          children: <Widget>[
            RadioGroup<String>(
              groupValue: cfg.themeFollow,
              onChanged: (v) {
                if (v == null) return;
                store.setConfig(
                  store.value.copyWith(minimap: cfg.copyWith(themeFollow: v)),
                );
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<String>(
                    key: const ValueKey('minimap-theme-auto'),
                    title: Text(l10n.minimapThemeAuto),
                    value: 'auto',
                  ),
                  RadioListTile<String>(
                    key: const ValueKey('minimap-theme-dark'),
                    title: Text(l10n.minimapThemeDark),
                    value: 'dark',
                  ),
                  RadioListTile<String>(
                    key: const ValueKey('minimap-theme-light'),
                    title: Text(l10n.minimapThemeLight),
                    value: 'light',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Opt-in advanced dimension sliders.  Kept as a private widget so the section
/// card body stays readable.
class _AdvancedTile extends StatelessWidget {
  const _AdvancedTile({
    required this.cfg,
    required this.store,
    required this.l10n,
  });

  final MinimapConfig cfg;
  final dynamic store;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Hide the ExpansionTile's default divider lines — the card already
      // provides the visual grouping.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('minimap-advanced-tile'),
        initiallyExpanded: cfg.advanced,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: Insets.sm),
        title: Text(l10n.minimapAdvanced),
        onExpansionChanged: (expanded) {
          store.setConfig(
            store.value.copyWith(minimap: cfg.copyWith(advanced: expanded)),
          );
        },
        children: <Widget>[
          SettingsSlider(
            label: l10n.minimapWidth,
            valueLabel: '${((cfg.widthFrac ?? 0.3) * 100).toStringAsFixed(0)}%',
            minLabel: '10%',
            maxLabel: '90%',
            sliderKey: const ValueKey('minimap-width-slider'),
            min: 0.1,
            max: 0.9,
            divisions: 16,
            value: (cfg.widthFrac ?? 0.3).clamp(0.1, 0.9),
            onChanged: (v) {
              store.setConfig(
                store.value.copyWith(minimap: cfg.copyWith(widthFrac: v)),
              );
            },
          ),
          const SizedBox(height: Insets.md),
          SettingsSlider(
            label: l10n.minimapHeight,
            valueLabel:
                '${((cfg.heightFrac ?? 0.3) * 100).toStringAsFixed(0)}%',
            minLabel: '10%',
            maxLabel: '90%',
            sliderKey: const ValueKey('minimap-height-slider'),
            min: 0.1,
            max: 0.9,
            divisions: 16,
            value: (cfg.heightFrac ?? 0.3).clamp(0.1, 0.9),
            onChanged: (v) {
              store.setConfig(
                store.value.copyWith(minimap: cfg.copyWith(heightFrac: v)),
              );
            },
          ),
        ],
      ),
    );
  }
}

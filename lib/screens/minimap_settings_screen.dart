import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ynaviAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildBody(context, l10n, store, cfg, ynaviAvailable: false),
          data: (available) =>
              _buildBody(context, l10n, store, cfg, ynaviAvailable: available),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ----------------------------------------------------------------
        // Enable toggle (gated by YNavi availability)
        // ----------------------------------------------------------------
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.minimapEnable),
                  if (!ynaviAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.minimapYnaviUnavailableHint,
                        key: const ValueKey('minimap-ynavi-hint'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
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
          ],
        ),

        const SizedBox(height: 24),

        // ----------------------------------------------------------------
        // Preset selector (basic mode)
        // ----------------------------------------------------------------
        Text(
          l10n.minimapSection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        if (!cfg.advanced) ...<Widget>[
          Text(l10n.minimapPreset),
          const SizedBox(height: 8),
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

        const SizedBox(height: 16),

        // ----------------------------------------------------------------
        // Advanced mode: manual dimension sliders (opt-in ExpansionTile)
        // ----------------------------------------------------------------
        ExpansionTile(
          key: const ValueKey('minimap-advanced-tile'),
          initiallyExpanded: cfg.advanced,
          title: Text(l10n.minimapAdvanced),
          onExpansionChanged: (expanded) {
            store.setConfig(
              store.value.copyWith(
                minimap: cfg.copyWith(advanced: expanded),
              ),
            );
          },
          children: <Widget>[
            // Width fraction slider.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.minimapWidth),
                  Row(
                    children: <Widget>[
                      const Text('10%'),
                      Expanded(
                        child: Slider(
                          key: const ValueKey('minimap-width-slider'),
                          min: 0.1,
                          max: 0.9,
                          divisions: 16,
                          value: (cfg.widthFrac ?? 0.3).clamp(0.1, 0.9),
                          label:
                              '${((cfg.widthFrac ?? 0.3) * 100).toStringAsFixed(0)}%',
                          onChanged: (v) {
                            store.setConfig(
                              store.value.copyWith(
                                minimap: cfg.copyWith(widthFrac: v),
                              ),
                            );
                          },
                        ),
                      ),
                      const Text('90%'),
                    ],
                  ),
                  Text(l10n.minimapHeight),
                  Row(
                    children: <Widget>[
                      const Text('10%'),
                      Expanded(
                        child: Slider(
                          key: const ValueKey('minimap-height-slider'),
                          min: 0.1,
                          max: 0.9,
                          divisions: 16,
                          value: (cfg.heightFrac ?? 0.3).clamp(0.1, 0.9),
                          label:
                              '${((cfg.heightFrac ?? 0.3) * 100).toStringAsFixed(0)}%',
                          onChanged: (v) {
                            store.setConfig(
                              store.value.copyWith(
                                minimap: cfg.copyWith(heightFrac: v),
                              ),
                            );
                          },
                        ),
                      ),
                      const Text('90%'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ----------------------------------------------------------------
        // Theme follow: System / Dark / Light
        // Dark/light auto: when themeFollow='auto', HUD palette resolves
        // using MediaQuery.platformBrightnessOf(context) at render time.
        // 'dark'/'light' force the respective palette regardless of system.
        // ----------------------------------------------------------------
        Text(
          l10n.minimapThemeSection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: cfg.themeFollow,
          onChanged: (v) {
            if (v == null) return;
            store.setConfig(
              store.value.copyWith(
                minimap: cfg.copyWith(themeFollow: v),
              ),
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
    );
  }
}

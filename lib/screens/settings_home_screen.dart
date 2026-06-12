import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../theme/app_theme.dart';
import 'diagnostics_screen.dart';
import 'hud_settings_screen.dart';
import 'install_screen.dart';
import 'language_settings_screen.dart';
import 'minimap_settings_screen.dart';
import 'usb_adb_screen.dart';

/// DHU Settings hub — the root screen of the DHU navigation shell.
///
/// Shows six sections as a grouped card: HUD, Minimap, Diagnostics, Language,
/// Install, and USB/ADB.  Language navigates to [LanguageSettingsScreen] which
/// hosts three clearly-separated sub-sections: App / System / Cluster
/// (Block 0015).  USB/ADB was moved here from Diagnostics (Block 0023 QA2-2)
/// to keep Diagnostics read-only.
class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          Card(
            child: Column(
              children: <Widget>[
                _SectionTile(
                  key: const ValueKey('nav-hud'),
                  icon: Icons.remove_red_eye_outlined,
                  title: l10n.sectionHud,
                  subtitle: l10n.sectionHudSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const HudSettingsScreen(),
                    ),
                  ),
                ),
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-minimap'),
                  icon: Icons.map_outlined,
                  title: l10n.sectionMinimap,
                  subtitle: l10n.sectionMinimapSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MinimapSettingsScreen(),
                    ),
                  ),
                ),
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-diagnostics'),
                  icon: Icons.monitor_heart_outlined,
                  title: l10n.sectionDiagnostics,
                  subtitle: l10n.sectionDiagnosticsSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                ),
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-language'),
                  icon: Icons.language,
                  title: l10n.sectionLanguage,
                  subtitle: l10n.sectionLanguageSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LanguageSettingsScreen(),
                    ),
                  ),
                ),
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-install'),
                  icon: Icons.download_outlined,
                  title: l10n.sectionInstall,
                  subtitle: l10n.sectionInstallSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const InstallScreen(),
                    ),
                  ),
                ),
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-usb'),
                  icon: Icons.usb_outlined,
                  title: l10n.sectionUsbAdb,
                  subtitle: l10n.sectionUsbAdbSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UsbAdbScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          // Contextual status footer — fills the lower half of the hub and
          // surfaces the two most relevant live states at a glance (QA2-5).
          _StatusFooter(l10n: l10n),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tile widget
// ---------------------------------------------------------------------------

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      leading: Icon(icon, size: Sizes.iconMd),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        size: Sizes.iconMd,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// Hairline divider between hub tiles, inset past the leading icon so the rule
/// aligns with the text column — the standard grouped-list look.
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: Insets.lg + Sizes.iconMd + Insets.lg);
}

// ---------------------------------------------------------------------------
// Status footer — small contextual bar below the hub card (QA2-5).
//
// Shows live HUD on/off and minimap on/off so the lower half of the premium
// DHU screen is never blank.  No new routes needed — it is purely read-only.
// ---------------------------------------------------------------------------

class _StatusFooter extends ConsumerWidget {
  const _StatusFooter({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCfg = ref.watch(appConfigProvider);
    final store = ref.watch(configStoreProvider);
    final cfg = asyncCfg.when(
      data: (c) => c,
      loading: () => store.value,
      error: (e, st) => store.value,
    );
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            cfg.hudEnabled
                ? Icons.remove_red_eye
                : Icons.remove_red_eye_outlined,
            size: 14,
            color: cfg.hudEnabled ? active : inactive,
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.sectionHud} ${cfg.hudEnabled ? "on" : "off"}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cfg.hudEnabled ? active : inactive,
            ),
          ),
          const SizedBox(width: Insets.xl),
          Icon(
            Icons.map_outlined,
            size: 14,
            color: cfg.minimap.enabled ? active : inactive,
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.sectionMinimap} ${cfg.minimap.enabled ? "on" : "off"}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cfg.minimap.enabled ? active : inactive,
            ),
          ),
        ],
      ),
    );
  }
}

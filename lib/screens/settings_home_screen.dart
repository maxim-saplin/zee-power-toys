import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'diagnostics_screen.dart';
import 'hud_settings_screen.dart';
import 'install_screen.dart';
import 'language_settings_screen.dart';
import 'minimap_settings_screen.dart';

/// DHU Settings hub — the root screen of the DHU navigation shell.
///
/// Shows five sections (HUD, Minimap, Diagnostics, Language, Install).
/// Language navigates to [LanguageSettingsScreen] which hosts three
/// clearly-separated sub-sections: App / System / Cluster (Block 0015).
/// Each section push-navigates with a plain Navigator/MaterialPageRoute —
/// no go_router needed for this shallow, non-deep-linked navigation tree.
class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: <Widget>[
          _SectionTile(
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

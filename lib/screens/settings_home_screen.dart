import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import 'hud_settings_screen.dart';

/// DHU Settings hub — the root screen of the DHU navigation shell.
///
/// Shows four sections (HUD, Diagnostics, Language, Install).  HUD and Language
/// are functional; Diagnostics and Install are placeholders for future Blocks.
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
            icon: Icons.monitor_heart_outlined,
            title: l10n.sectionDiagnostics,
            subtitle: l10n.sectionDiagnosticsSubtitle,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _PlaceholderScreen(title: l10n.sectionDiagnostics),
              ),
            ),
          ),
          _SectionTile(
            icon: Icons.language,
            title: l10n.sectionLanguage,
            subtitle: l10n.sectionLanguageSubtitle,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const _LanguageScreen(),
              ),
            ),
          ),
          _SectionTile(
            icon: Icons.download_outlined,
            title: l10n.sectionInstall,
            subtitle: l10n.sectionInstallSubtitle,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _PlaceholderScreen(title: l10n.sectionInstall),
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

// ---------------------------------------------------------------------------
// Language picker screen
// ---------------------------------------------------------------------------

/// Language picker — sets AppConfig.locale (null = system, 'en', 'ru').
/// Persisted via ConfigStore; live-updates the DHU MaterialApp locale.
class _LanguageScreen extends ConsumerWidget {
  const _LanguageScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(configStoreProvider);
    final current = ref.watch(appConfigProvider).when(
      data: (cfg) => cfg.locale,
      loading: () => store.value.locale,
      error: (err, st) => store.value.locale,
    );

    void pick(String? code) =>
        store.setConfig(store.value.copyWith(locale: code));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: RadioGroup<String?>(
        groupValue: current,
        onChanged: (v) => pick(v),
        child: ListView(
          children: <Widget>[
            RadioListTile<String?>(
              key: const ValueKey('lang-system'),
              title: Text(l10n.languageSystem),
              value: null,
            ),
            RadioListTile<String?>(
              key: const ValueKey('lang-en'),
              title: Text(l10n.languageEnglish),
              value: 'en',
            ),
            RadioListTile<String?>(
              key: const ValueKey('lang-ru'),
              title: Text(l10n.languageRussian),
              value: 'ru',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder screen for Diagnostics / Install
// ---------------------------------------------------------------------------

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../widgets/settings_layout.dart';

/// App about + data credits (0043-A).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        key: const ValueKey('about-scroll'),
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: l10n.aboutAppSection,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.aboutAppName),
                subtitle: Text('${l10n.aboutVersion} $appVersion'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.aboutCreditsSection,
            children: [
              ListTile(
                key: const ValueKey('about-speedcam-credit'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.aboutSpeedcamCreditTitle),
                subtitle: Text(l10n.aboutSpeedcamCreditBody),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/settings_layout.dart';

/// App about + data credits (0043-A).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

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
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final info = snap.data;
                    final ver = info == null
                        ? '…'
                        : '${info.version}+${info.buildNumber}';
                    return Text('${l10n.aboutVersion} $ver');
                  },
                ),
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

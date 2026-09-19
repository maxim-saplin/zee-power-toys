import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/install_targets.dart';
import '../services/installer.dart';
import '../services/package_status.dart';
import '../theme/app_theme.dart';
import 'diagnostics_screen.dart';
import 'hud_settings_screen.dart';
import 'install_screen.dart';
import 'language_settings_screen.dart';
import 'minimap_settings_screen.dart';
import 'simulate_screen.dart';
import 'usb_adb_screen.dart';

/// DHU home — two-column landing (Block 0027).
///
/// Welcome column: short intro + companion APK status (Launcher / YNavi) with
/// Install when missing. Sections column: existing settings tiles → full-screen.
class SettingsHomeScreen extends ConsumerStatefulWidget {
  const SettingsHomeScreen({super.key});

  @override
  ConsumerState<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends ConsumerState<SettingsHomeScreen> {
  PackageInstallState? _launcher;
  PackageInstallState? _ynavi;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final probe = ref.read(packageStatusProvider);
    final launcher = await probe.statusFor(CompanionPackages.launcher);
    final ynavi = await probe.statusFor(CompanionPackages.ynavi);
    if (!mounted) return;
    setState(() {
      _launcher = launcher;
      _ynavi = ynavi;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final welcome = _WelcomeColumn(
            l10n: l10n,
            launcher: _launcher,
            ynavi: _ynavi,
            onRefresh: _refreshStatus,
          );
          final sections = _SectionsColumn(l10n: l10n);
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: welcome),
                  const SizedBox(width: Insets.lg),
                  Expanded(flex: 6, child: sections),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: <Widget>[
              welcome,
              const SizedBox(height: Insets.xl),
              sections,
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome column
// ---------------------------------------------------------------------------

class _WelcomeColumn extends StatelessWidget {
  const _WelcomeColumn({
    required this.l10n,
    required this.launcher,
    required this.ynavi,
    required this.onRefresh,
  });

  final AppLocalizations l10n;
  final PackageInstallState? launcher;
  final PackageInstallState? ynavi;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.homeWelcomeTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Insets.sm),
        Text(
          l10n.homeWelcomeBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xl),
        Text(l10n.homeCompanionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: Insets.md),
        _CompanionCard(
          key: const ValueKey('companion-launcher'),
          name: l10n.installLauncherName,
          description: l10n.installLauncherDesc,
          status: launcher,
          asset: kLauncherAsset,
          installKey: const ValueKey('home-install-launcher'),
          onDone: onRefresh,
        ),
        const SizedBox(height: Insets.md),
        _CompanionCard(
          key: const ValueKey('companion-ynavi'),
          name: l10n.installYnaviName,
          description: l10n.installYnaviDesc,
          status: ynavi,
          asset: kYnaviAsset,
          installKey: const ValueKey('home-install-ynavi'),
          onDone: onRefresh,
        ),
        const SizedBox(height: Insets.xl),
        const _StatusFooter(),
      ],
    );
  }
}

class _CompanionCard extends ConsumerStatefulWidget {
  const _CompanionCard({
    super.key,
    required this.name,
    required this.description,
    required this.status,
    required this.asset,
    required this.installKey,
    required this.onDone,
  });

  final String name;
  final String description;
  final PackageInstallState? status;
  final GithubAsset asset;
  final Key installKey;
  final VoidCallback onDone;

  @override
  ConsumerState<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends ConsumerState<_CompanionCard> {
  StreamSubscription<InstallProgress>? _sub;
  InstallProgress? _progress;

  bool get _busy =>
      _progress != null &&
      _progress!.phase != InstallPhase.done &&
      _progress!.phase != InstallPhase.failed;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startInstall() {
    if (_busy) return;
    setState(
      () => _progress = const InstallProgress(
        phase: InstallPhase.downloading,
        fraction: 0,
      ),
    );
    final installer = ref.read(installerProvider);
    _sub = installer.install(widget.asset).listen(
      (p) => setState(() => _progress = p),
      onDone: () {
        widget.onDone();
      },
      onError: (Object e) => setState(
        () => _progress = InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0,
          message: e.toString(),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PackageInstallState? s) {
    switch (s) {
      case PackageInstallState.installed:
        return l10n.homeStatusInstalled;
      case PackageInstallState.missing:
        return l10n.homeStatusMissing;
      case PackageInstallState.unknown:
      case null:
        return l10n.homeStatusUnknown;
    }
  }

  Color _statusColor(ColorScheme cs, PackageInstallState? s) {
    switch (s) {
      case PackageInstallState.installed:
        return cs.primary;
      case PackageInstallState.missing:
        return cs.error;
      case PackageInstallState.unknown:
      case null:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final showInstall = widget.status == PackageInstallState.missing ||
        widget.status == PackageInstallState.unknown;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: Insets.xs),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _statusLabel(l10n, widget.status),
                  key: ValueKey('status-${widget.key}'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _statusColor(cs, widget.status),
                      ),
                ),
              ],
            ),
            if (showInstall) ...<Widget>[
              const SizedBox(height: Insets.md),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  key: widget.installKey,
                  onPressed: _busy ? null : _startInstall,
                  child: Text(l10n.homeInstallAction),
                ),
              ),
            ],
            if (_progress != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              LinearProgressIndicator(
                value: _busy || _progress!.phase == InstallPhase.done
                    ? _progress!.fraction
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections column
// ---------------------------------------------------------------------------

class _SectionsColumn extends StatelessWidget {
  const _SectionsColumn({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.homeSectionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: Insets.md),
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
              if (kDebugMode) ...<Widget>[
                const _TileDivider(),
                _SectionTile(
                  key: const ValueKey('nav-simulate'),
                  icon: Icons.bolt_outlined,
                  title: l10n.sectionSimulate,
                  subtitle: l10n.sectionSimulateSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SimulateScreen(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: Insets.lg + Sizes.iconMd + Insets.lg);
}

class _StatusFooter extends ConsumerWidget {
  const _StatusFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
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

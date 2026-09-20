import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../services/app_self_update.dart';
import '../services/install_targets.dart';
import '../services/installer.dart';
import '../theme/app_theme.dart';

/// Install screen — companions from GitHub Releases + self-update (0069).
class InstallScreen extends ConsumerWidget {
  const InstallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final installer = ref.read(installerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.installTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          _SelfUpdateCard(
            key: const ValueKey('card-self-update'),
            installer: installer,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-launcher'),
            installKey: const ValueKey('install-launcher'),
            name: l10n.installLauncherName,
            description: l10n.installLauncherDesc,
            asset: kLauncherAsset,
            installer: installer,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-ynavi'),
            installKey: const ValueKey('install-ynavi'),
            name: l10n.installYnaviName,
            description: l10n.installYnaviDesc,
            asset: kYnaviAsset,
            installer: installer,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-ynavi-os7'),
            installKey: const ValueKey('install-ynavi-os7'),
            name: l10n.installYnaviOs7Name,
            description: l10n.installYnaviOs7Desc,
            asset: kYnaviOs7Asset,
            installer: installer,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Self-update (0069)
// ---------------------------------------------------------------------------

class _SelfUpdateCard extends StatefulWidget {
  const _SelfUpdateCard({super.key, required this.installer});

  final Installer installer;

  @override
  State<_SelfUpdateCard> createState() => _SelfUpdateCardState();
}

class _SelfUpdateCardState extends State<_SelfUpdateCard> {
  AppUpdateCheck? _check;
  bool _checking = false;
  StreamSubscription<InstallProgress>? _sub;
  InstallProgress? _progress;

  bool get _busyInstall =>
      _progress != null &&
      _progress!.phase != InstallPhase.done &&
      _progress!.phase != InstallPhase.failed;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _runCheck() async {
    if (_checking || _busyInstall) return;
    setState(() {
      _checking = true;
      _check = null;
    });
    final result = await AppSelfUpdate().check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _check = result;
    });
  }

  void _startUpdate(GithubAsset asset) {
    if (_busyInstall) return;
    setState(
      () => _progress = const InstallProgress(
        phase: InstallPhase.downloading,
        fraction: 0.0,
      ),
    );
    _sub = widget.installer.install(asset).listen(
      (progress) => setState(() => _progress = progress),
      onDone: () {
        if (_progress?.phase != InstallPhase.done &&
            _progress?.phase != InstallPhase.failed) {
          setState(
            () => _progress = const InstallProgress(
              phase: InstallPhase.done,
              fraction: 1.0,
            ),
          );
        }
      },
      onError: (Object err) => setState(
        () => _progress = InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0.0,
          message: err.toString(),
        ),
      ),
      cancelOnError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final available = _check is AppUpdateAvailable
        ? _check as AppUpdateAvailable
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: Insets.xs,
                    right: Insets.md,
                  ),
                  child: Icon(
                    Icons.system_update_alt,
                    size: Sizes.iconMd,
                    color: cs.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.updateCardName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        l10n.updateCardDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                if (available != null)
                  ElevatedButton(
                    key: const ValueKey('update-install'),
                    onPressed: _busyInstall
                        ? null
                        : () => _startUpdate(available.asset),
                    child: Text(l10n.updateInstallButton),
                  )
                else
                  ElevatedButton(
                    key: const ValueKey('update-check'),
                    onPressed: (_checking || _busyInstall) ? null : _runCheck,
                    child: Text(l10n.updateCheckButton),
                  ),
              ],
            ),
            if (_checking || _check != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _statusLabel(l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _check is AppUpdateCheckFailed
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.button),
                child: LinearProgressIndicator(
                  value: _busyInstall || _progress!.phase == InstallPhase.done
                      ? _progress!.fraction
                      : null,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: _progress!.phase == InstallPhase.failed
                      ? cs.error
                      : null,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                _phaseLabel(l10n, _progress!.phase, _progress!.message),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _progress!.phase == InstallPhase.failed
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_checking) return l10n.updateStatusChecking;
    final c = _check;
    if (c is AppUpdateAvailable) {
      return l10n.updateStatusAvailable(c.remoteLabel);
    }
    if (c is AppUpdateUpToDate) return l10n.updateStatusUpToDate;
    if (c is AppUpdateNonePublished) return l10n.updateStatusNone;
    if (c is AppUpdateCheckFailed) {
      return l10n.updateStatusFailed(c.message);
    }
    return '';
  }

  static String _phaseLabel(
    AppLocalizations l10n,
    InstallPhase phase,
    String? message,
  ) {
    switch (phase) {
      case InstallPhase.downloading:
        return l10n.installPhaseDownloading;
      case InstallPhase.installing:
        return l10n.installPhaseInstalling;
      case InstallPhase.done:
        return l10n.installPhaseDone;
      case InstallPhase.failed:
        return message != null
            ? '${l10n.installPhaseFailed}: $message'
            : l10n.installPhaseFailed;
    }
  }
}

// ---------------------------------------------------------------------------
// Individual install target card
// ---------------------------------------------------------------------------

class _InstallCard extends StatefulWidget {
  const _InstallCard({
    super.key,
    required this.installKey,
    required this.name,
    required this.description,
    required this.asset,
    required this.installer,
  });

  final Key installKey;
  final String name;
  final String description;
  final GithubAsset asset;
  final Installer installer;

  @override
  State<_InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<_InstallCard> {
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
        fraction: 0.0,
      ),
    );
    _sub = widget.installer
        .install(widget.asset)
        .listen(
          (progress) => setState(() => _progress = progress),
          onDone: () {
            if (_progress?.phase != InstallPhase.done &&
                _progress?.phase != InstallPhase.failed) {
              setState(
                () => _progress = const InstallProgress(
                  phase: InstallPhase.done,
                  fraction: 1.0,
                ),
              );
            }
          },
          onError: (Object err) => setState(
            () => _progress = InstallProgress(
              phase: InstallPhase.failed,
              fraction: 0.0,
              message: err.toString(),
            ),
          ),
          cancelOnError: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final phase = _progress?.phase;
    final fraction = _progress?.fraction ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: Insets.xs,
                    right: Insets.md,
                  ),
                  child: Icon(
                    Icons.archive_outlined,
                    size: Sizes.iconMd,
                    color: cs.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
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
                const SizedBox(width: Insets.md),
                ElevatedButton(
                  key: widget.installKey,
                  onPressed: _busy ? null : _startInstall,
                  child: Text(l10n.installButtonLabel),
                ),
              ],
            ),
            if (_progress != null) ...[
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.button),
                child: LinearProgressIndicator(
                  value: _busy || phase == InstallPhase.done ? fraction : null,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: phase == InstallPhase.failed ? cs.error : null,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                _phaseLabel(l10n, phase, _progress?.message),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: phase == InstallPhase.failed
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _phaseLabel(
    AppLocalizations l10n,
    InstallPhase? phase,
    String? message,
  ) {
    switch (phase) {
      case InstallPhase.downloading:
        return l10n.installPhaseDownloading;
      case InstallPhase.installing:
        return l10n.installPhaseInstalling;
      case InstallPhase.done:
        return l10n.installPhaseDone;
      case InstallPhase.failed:
        return message != null
            ? '${l10n.installPhaseFailed}: $message'
            : l10n.installPhaseFailed;
      case null:
        return '';
    }
  }
}

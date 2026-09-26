import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../services/app_self_update.dart';
import '../services/install_targets.dart';
import '../services/installer.dart';
import '../services/package_status.dart';
import '../services/release_compare.dart';
import '../theme/app_theme.dart';

/// Install screen — companions from GitHub Releases + self-update (0069 / 0103).
class InstallScreen extends ConsumerWidget {
  const InstallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final installer = ref.read(installerProvider);
    final packages = ref.read(packageStatusProvider);
    final updateChecker = ref.read(appUpdateCheckerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.installTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          _SelfUpdateCard(
            key: const ValueKey('card-self-update'),
            installer: installer,
            updateChecker: updateChecker,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-launcher'),
            installKey: const ValueKey('install-launcher'),
            name: l10n.installLauncherName,
            description: l10n.installLauncherDesc,
            asset: kLauncherAsset,
            packageName: CompanionPackages.launcher,
            releaseVersionCode: kLauncherReleaseVersionCode,
            releaseLabel: kLauncherAsset.releaseTag ?? 'launcher-670',
            installer: installer,
            packages: packages,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-ynavi'),
            installKey: const ValueKey('install-ynavi'),
            name: l10n.installYnaviName,
            description: l10n.installYnaviDesc,
            asset: kYnaviAsset,
            packageName: CompanionPackages.ynavi,
            releaseVersionCode: kYnaviReleaseVersionCode,
            releaseLabel: kYnaviUpstreamVersionBuild,
            installer: installer,
            packages: packages,
          ),
          const SizedBox(height: Insets.md),
          _InstallCard(
            key: const ValueKey('card-ynavi-os7'),
            installKey: const ValueKey('install-ynavi-os7'),
            name: l10n.installYnaviOs7Name,
            description: l10n.installYnaviOs7Desc,
            asset: kYnaviOs7Asset,
            packageName: CompanionPackages.ynavi,
            releaseVersionCode: kYnaviReleaseVersionCode,
            releaseLabel: kYnaviUpstreamVersionBuild,
            installer: installer,
            packages: packages,
          ),
        ],
      ),
    );
  }
}

/// Progress-bar value for [InstallProgress].
///
/// Download stays determinate. Install uses an indeterminate bar (0086): native
/// used to emit `installing` at 0.8 after download hit ~1.0, which looked like
/// the bar going backwards. PackageInstaller has no byte-level progress anyway.
double? installProgressBarValue(InstallProgress progress) {
  switch (progress.phase) {
    case InstallPhase.downloading:
      return progress.fraction;
    case InstallPhase.installing:
      return null;
    case InstallPhase.done:
      return progress.fraction;
    case InstallPhase.failed:
      return null;
  }
}

String releaseActionButtonLabel(AppLocalizations l10n, ReleaseActionKind kind) {
  switch (kind) {
    case ReleaseActionKind.install:
      return l10n.installActionInstall;
    case ReleaseActionKind.installOrUpdate:
      return l10n.installButtonLabel;
    case ReleaseActionKind.update:
      return l10n.updateInstallButton;
    case ReleaseActionKind.reinstall:
    case ReleaseActionKind.tipAhead:
      return l10n.updateReinstallButton;
  }
}

// ---------------------------------------------------------------------------
// Self-update (0069 / 0103)
// ---------------------------------------------------------------------------

class _SelfUpdateCard extends StatefulWidget {
  const _SelfUpdateCard({
    super.key,
    required this.installer,
    required this.updateChecker,
  });

  final Installer installer;
  final AppUpdateChecker updateChecker;

  @override
  State<_SelfUpdateCard> createState() => _SelfUpdateCardState();
}

class _SelfUpdateCardState extends State<_SelfUpdateCard> {
  AppUpdateCheck? _check;
  bool _checking = false;
  /// Soft-fail detail when [_check] retains a prior good result (0115).
  String? _lastError;
  StreamSubscription<InstallProgress>? _sub;
  InstallProgress? _progress;

  bool get _busyInstall =>
      _progress != null &&
      _progress!.phase != InstallPhase.done &&
      _progress!.phase != InstallPhase.failed;

  GithubAsset? get _actionAsset {
    final c = _check;
    if (c is AppUpdateAvailable) return c.asset;
    if (c is AppUpdateReinstall) return c.asset;
    if (c is AppUpdateTipAhead) return c.asset;
    return null;
  }

  @override
  void initState() {
    super.initState();
    // 0115: auto-check on open / resume (parity with companion _refreshProbe).
    _runCheck();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _runCheck() async {
    if (_checking || _busyInstall) return;
    final previous = _check;
    setState(() {
      _checking = true;
      // Keep last known visible under "Checking…" until result arrives (soft).
      if (previous is AppUpdateCheckFailed) {
        _check = null;
      }
    });
    final result = await widget.updateChecker();
    if (!mounted) return;
    setState(() {
      _checking = false;
      // Soft fail: keep last good result when GH/offline fails.
      if (result is AppUpdateCheckFailed &&
          previous != null &&
          previous is! AppUpdateCheckFailed) {
        _check = previous;
        _lastError = result.message;
      } else {
        _check = result;
        _lastError = result is AppUpdateCheckFailed ? result.message : null;
      }
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
    final asset = _actionAsset;
    final isUpdate = _check is AppUpdateAvailable;
    final isReinstall =
        _check is AppUpdateReinstall || _check is AppUpdateTipAhead;

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
                if (asset != null && (isUpdate || isReinstall))
                  ElevatedButton(
                    key: ValueKey(isUpdate ? 'update-install' : 'update-reinstall'),
                    onPressed: _busyInstall ? null : () => _startUpdate(asset),
                    child: Text(
                      isUpdate
                          ? l10n.updateInstallButton
                          : l10n.updateReinstallButton,
                    ),
                  )
                else
                  ElevatedButton(
                    key: const ValueKey('update-check'),
                    onPressed: (_checking || _busyInstall) ? null : _runCheck,
                    child: Text(l10n.updateCheckButton),
                  ),
              ],
            ),
            if (_checking || _check != null || _lastError != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _statusLabel(l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: (_check is AppUpdateCheckFailed || _lastError != null)
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
                  value: installProgressBarValue(_progress!),
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
    final err = _lastError;
    final c = _check;
    if (c is AppUpdateAvailable) {
      final base = l10n.updateStatusAvailable(c.remoteLabel);
      return err != null ? '$base — ${l10n.updateStatusFailed(err)}' : base;
    }
    if (c is AppUpdateReinstall) {
      final base = l10n.updateStatusUpToDate;
      return err != null ? '$base — ${l10n.updateStatusFailed(err)}' : base;
    }
    if (c is AppUpdateTipAhead) {
      final base = l10n.updateStatusTipAhead(c.remoteLabel);
      return err != null ? '$base — ${l10n.updateStatusFailed(err)}' : base;
    }
    if (c is AppUpdateUpToDate) {
      final base = l10n.updateStatusUpToDate;
      return err != null ? '$base — ${l10n.updateStatusFailed(err)}' : base;
    }
    if (c is AppUpdateNonePublished) {
      final base = l10n.updateStatusNone;
      return err != null ? '$base — ${l10n.updateStatusFailed(err)}' : base;
    }
    if (c is AppUpdateCheckFailed) {
      return l10n.updateStatusFailed(c.message);
    }
    if (err != null) return l10n.updateStatusFailed(err);
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
// Individual install target card (0103: Update / Reinstall vs probe)
// ---------------------------------------------------------------------------

class _InstallCard extends StatefulWidget {
  const _InstallCard({
    super.key,
    required this.installKey,
    required this.name,
    required this.description,
    required this.asset,
    required this.packageName,
    required this.releaseVersionCode,
    required this.releaseLabel,
    required this.installer,
    required this.packages,
  });

  final Key installKey;
  final String name;
  final String description;
  final GithubAsset asset;
  final String packageName;
  final int releaseVersionCode;
  final String releaseLabel;
  final Installer installer;
  final PackageStatus packages;

  @override
  State<_InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<_InstallCard> {
  StreamSubscription<InstallProgress>? _sub;
  InstallProgress? _progress;
  PackageProbe? _probe;
  bool _probing = true;

  bool get _busy =>
      _progress != null &&
      _progress!.phase != InstallPhase.done &&
      _progress!.phase != InstallPhase.failed;

  ReleaseActionKind get _action {
    final p = _probe;
    if (p == null) return ReleaseActionKind.installOrUpdate;
    return releaseActionFor(
      state: p.state,
      installedCode: p.versionCode,
      releaseCode: widget.releaseVersionCode,
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshProbe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshProbe() async {
    setState(() => _probing = true);
    final probe = await widget.packages.probe(widget.packageName);
    if (!mounted) return;
    setState(() {
      _probe = probe;
      _probing = false;
    });
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
            _refreshProbe();
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
    final action = _action;
    final buttonLabel = releaseActionButtonLabel(l10n, action);
    final status = _companionStatus(l10n, action);

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
                  child: Text(buttonLabel),
                ),
              ],
            ),
            if (!_probing && status != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                status,
                key: ValueKey('install-status-${widget.packageName}-${widget.asset.path}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.button),
                child: LinearProgressIndicator(
                  value: installProgressBarValue(_progress!),
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

  String? _companionStatus(AppLocalizations l10n, ReleaseActionKind action) {
    switch (action) {
      case ReleaseActionKind.install:
        return null;
      case ReleaseActionKind.installOrUpdate:
        return null;
      case ReleaseActionKind.update:
        return l10n.updateStatusAvailable(widget.releaseLabel);
      case ReleaseActionKind.reinstall:
        return l10n.updateStatusUpToDate;
      case ReleaseActionKind.tipAhead:
        return l10n.updateStatusTipAhead(widget.releaseLabel);
    }
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../services/install_targets.dart';
import '../services/installer.dart';

/// Install screen — download and install the Modded Launcher and YNavi mod
/// from configured GitHub releases.
///
/// Each target is represented as a [_InstallCard] that holds its own install
/// stream subscription so two installs can run concurrently without
/// interfering.
class InstallScreen extends ConsumerWidget {
  const InstallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final installer = ref.read(installerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.installTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _InstallCard(
            key: const ValueKey('card-launcher'),
            installKey: const ValueKey('install-launcher'),
            name: l10n.installLauncherName,
            description: l10n.installLauncherDesc,
            asset: kLauncherAsset,
            installer: installer,
          ),
          const SizedBox(height: 12),
          _InstallCard(
            key: const ValueKey('card-ynavi'),
            installKey: const ValueKey('install-ynavi'),
            name: l10n.installYnaviName,
            description: l10n.installYnaviDesc,
            asset: kYnaviAsset,
            installer: installer,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual install target card
// ---------------------------------------------------------------------------

/// Displays one installable target.  The card is self-contained: it manages
/// its own install stream and progress state so cards are fully independent.
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
    setState(() => _progress = const InstallProgress(
          phase: InstallPhase.downloading,
          fraction: 0.0,
        ));
    _sub = widget.installer.install(widget.asset).listen(
      (progress) => setState(() => _progress = progress),
      onDone: () {
        // Stream closed without a final event: treat as done.
        if (_progress?.phase != InstallPhase.done &&
            _progress?.phase != InstallPhase.failed) {
          setState(() => _progress = const InstallProgress(
                phase: InstallPhase.done,
                fraction: 1.0,
              ));
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Header row ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  key: widget.installKey,
                  onPressed: _busy ? null : _startInstall,
                  child: Text(l10n.installButtonLabel),
                ),
              ],
            ),

            // --- Progress section — only visible when an install is active ---
            if (_progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _busy || phase == InstallPhase.done ? fraction : null,
                backgroundColor: cs.surfaceContainerHighest,
                color: phase == InstallPhase.failed ? cs.error : null,
              ),
              const SizedBox(height: 6),
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

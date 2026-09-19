import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../services/speedcam_pack_store.dart';
import '../widgets/settings_layout.dart';

/// Stub Speedcam settings — pack status + manual Update (0031).
class SpeedcamSettingsScreen extends ConsumerStatefulWidget {
  const SpeedcamSettingsScreen({super.key});

  @override
  ConsumerState<SpeedcamSettingsScreen> createState() =>
      _SpeedcamSettingsScreenState();
}

class _SpeedcamSettingsScreenState
    extends ConsumerState<SpeedcamSettingsScreen> {
  SpeedcamPackMeta? _meta;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final store = ref.read(speedcamPackStoreProvider);
    final meta = await store.current(SpeedcamPackIds.by);
    if (!mounted) return;
    setState(() => _meta = meta);
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(speedcamPackStoreProvider);
      final meta = await store.updatePack(SpeedcamPackIds.by);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final meta = _meta;
    final status = meta == null
        ? l10n.speedcamPackMissing
        : l10n.speedcamPackStatus(
            meta.camCount,
            meta.fetchedAt.toLocal().toIso8601String(),
          );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speedcamTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: l10n.speedcamPackSection,
            children: [
              ListTile(
                key: const ValueKey('speedcam-pack-status'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamPackBy),
                subtitle: Text(_error ?? status),
              ),
              FilledButton(
                key: const ValueKey('speedcam-pack-update'),
                onPressed: _busy ? null : _update,
                child: Text(
                  _busy ? l10n.speedcamPackUpdating : l10n.speedcamPackUpdate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

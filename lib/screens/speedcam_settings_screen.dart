import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';
import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../services/speedcam_pack_store.dart';
import '../widgets/settings_layout.dart';

/// Speedcam settings — pack + large DHU radar + config (0031/0034).
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
      await ref.read(speedcamServiceProvider).reloadFromPack();
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

  Future<void> _patchSpeedcam(SpeedcamConfig Function(SpeedcamConfig) fn) async {
    final store = ref.read(configStoreProvider);
    final cfg = store.value;
    await store.setConfig(cfg.copyWith(speedcam: fn(cfg.speedcam)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final meta = _meta;
    final sc = ref.watch(speedcamConfigProvider);
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
            title: l10n.speedcamRadarSection,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: SpeedcamRadarWidget(
                    variant: SpeedcamRadarVariant.dhuLarge,
                    alwaysShow: true,
                    displayRadiusM: sc.dhuRangeM,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('speedcam-hud-radar'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamHudRadarEnable),
                value: sc.hudRadarEnabled,
                onChanged: (v) => _patchSpeedcam(
                  (c) => c.copyWith(hudRadarEnabled: v),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('speedcam-sound'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamSoundEnable),
                value: sc.soundEnabled,
                onChanged: (v) => _patchSpeedcam(
                  (c) => c.copyWith(soundEnabled: v),
                ),
              ),
              SettingsSlider(
                label: l10n.speedcamDhuRange,
                valueLabel: '${sc.dhuRangeM.round()} m',
                minLabel: '500',
                maxLabel: '3000',
                sliderKey: const ValueKey('speedcam-dhu-range'),
                min: 500,
                max: 3000,
                divisions: 25,
                value: sc.dhuRangeM.clamp(500, 3000),
                onChanged: (v) => _patchSpeedcam(
                  (c) => c.copyWith(dhuRangeM: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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

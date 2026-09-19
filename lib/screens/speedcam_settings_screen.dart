import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';
import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';
import '../widgets/settings_layout.dart';

/// Speedcam settings — radar, harvest policy, local pack DB (0031/0034/0037).
class SpeedcamSettingsScreen extends ConsumerStatefulWidget {
  const SpeedcamSettingsScreen({super.key});

  @override
  ConsumerState<SpeedcamSettingsScreen> createState() =>
      _SpeedcamSettingsScreenState();
}

class _SpeedcamSettingsScreenState
    extends ConsumerState<SpeedcamSettingsScreen> {
  SpeedcamPackMeta? _meta;
  List<SpeedcamPoint> _sampleCams = const [];
  String? _error;
  bool _busy = false;
  String? _policyNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _reloadLocal();
    await _applyRefreshPolicy();
  }

  Future<void> _reloadLocal() async {
    final store = ref.read(speedcamPackStoreProvider);
    final meta = await store.current(SpeedcamPackIds.by);
    final cams = await store.loadCams(SpeedcamPackIds.by);
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _sampleCams = cams.take(12).toList();
    });
  }

  Future<void> _applyRefreshPolicy() async {
    final sc = ref.read(speedcamConfigProvider);
    if (sc.refreshPolicy != SpeedcamRefreshPolicy.ifStale) return;
    setState(() {
      _busy = true;
      _error = null;
      _policyNote = null;
    });
    try {
      final store = ref.read(speedcamPackStoreProvider);
      final before = await store.current(SpeedcamPackIds.by);
      final meta = await store.refreshIfNeeded(
        packId: SpeedcamPackIds.by,
        ifStale: true,
        staleAfterDays: sc.staleAfterDays,
      );
      if (meta != null) {
        await ref.read(speedcamServiceProvider).reloadFromPack();
      }
      final cams = meta == null
          ? const <SpeedcamPoint>[]
          : await store.loadCams(SpeedcamPackIds.by);
      if (!mounted) return;
      final refreshed = before == null ||
          (meta != null && meta.fetchedAt != before.fetchedAt);
      setState(() {
        _meta = meta;
        _sampleCams = cams.take(12).toList();
        _busy = false;
        _policyNote = refreshed
            ? 'Refreshed (stale or missing)'
            : 'Pack still fresh (< ${sc.staleAfterDays}d)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
      _policyNote = null;
    });
    try {
      final store = ref.read(speedcamPackStoreProvider);
      final meta = await store.updatePack(SpeedcamPackIds.by);
      await ref.read(speedcamServiceProvider).reloadFromPack();
      final cams = await store.loadCams(SpeedcamPackIds.by);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _sampleCams = cams.take(12).toList();
        _busy = false;
        _policyNote = 'Manual update ok';
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
    final age = meta?.age();
    final ageLabel = age == null
        ? '—'
        : age.inDays >= 1
            ? '${age.inDays}d'
            : age.inHours >= 1
                ? '${age.inHours}h'
                : '${age.inMinutes}m';
    final stale = meta?.isStale(afterDays: sc.staleAfterDays) ?? true;

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
            title: l10n.speedcamDbSection,
            children: [
              ListTile(
                key: const ValueKey('speedcam-db-region'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbRegion),
                subtitle: Text(meta?.regionLabel ?? l10n.speedcamPackBy),
              ),
              ListTile(
                key: const ValueKey('speedcam-db-source'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbSource),
                subtitle: Text(meta?.source ?? '—'),
              ),
              ListTile(
                key: const ValueKey('speedcam-db-fetched'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbFetched),
                subtitle: Text(
                  meta == null
                      ? l10n.speedcamPackMissing
                      : meta.fetchedAt.toLocal().toIso8601String(),
                ),
              ),
              ListTile(
                key: const ValueKey('speedcam-db-age'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbAge),
                subtitle: Text(
                  meta == null
                      ? '—'
                      : '$ageLabel${stale ? ' · STALE' : ' · fresh'}',
                ),
              ),
              ListTile(
                key: const ValueKey('speedcam-db-count'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbCount),
                subtitle: Text('${meta?.camCount ?? 0}'),
              ),
              if (_sampleCams.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.speedcamDbSample,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ..._sampleCams.map(
                  (c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.id),
                    subtitle: Text(
                      '${c.lat.toStringAsFixed(4)}, ${c.lon.toStringAsFixed(4)}'
                      '${c.maxspeed != null ? ' · ${c.maxspeed}' : ''}'
                      '${c.direction != null ? ' · ${c.direction}' : ''}',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.speedcamHarvestSection,
            children: [
              Text(l10n.speedcamRefreshPolicy, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<SpeedcamRefreshPolicy>(
                key: const ValueKey('speedcam-refresh-policy'),
                segments: [
                  ButtonSegment(
                    value: SpeedcamRefreshPolicy.manualOnly,
                    label: Text(l10n.speedcamRefreshManual),
                  ),
                  ButtonSegment(
                    value: SpeedcamRefreshPolicy.ifStale,
                    label: Text(l10n.speedcamRefreshIfStale),
                  ),
                ],
                selected: {sc.refreshPolicy},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  _patchSpeedcam((c) => c.copyWith(refreshPolicy: sel.first));
                },
              ),
              if (sc.refreshPolicy == SpeedcamRefreshPolicy.ifStale) ...[
                const SizedBox(height: 12),
                SettingsSlider(
                  label: l10n.speedcamStaleDays,
                  valueLabel: '${sc.staleAfterDays}d',
                  minLabel: '1',
                  maxLabel: '30',
                  sliderKey: const ValueKey('speedcam-stale-days'),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  value: sc.staleAfterDays.toDouble().clamp(1, 30),
                  onChanged: (v) => _patchSpeedcam(
                    (c) => c.copyWith(staleAfterDays: v.round()),
                  ),
                ),
              ],
              if (_policyNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_policyNote!, key: const ValueKey('speedcam-policy-note')),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
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

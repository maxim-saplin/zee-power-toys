import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/speedcam_radar_widget.dart';
import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/speedcam.dart';
import '../providers/services.dart';
import '../services/config_store.dart';
import '../services/speedcam.dart';
import '../services/default_speedcam_service.dart';
import '../services/speedcam_pack_store.dart';
import '../widgets/settings_layout.dart';
import '../widgets/speedcam_pack_map_preview.dart';
import '../services/fakes/fake_speedcam_service.dart';

/// Speedcam settings — harvest/DB first (0037), then radar (0034).
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
  List<SpeedcamPoint> _allCams = const [];
  String? _error;
  bool _busy = false;
  bool _demoActive = false;
  String? _policyNote;

  SpeedcamConfig get _speedcamCfg =>
      ref.read(configStoreProvider).value.speedcam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _reloadLocal();
    // 0050 HARD: prompt for location before GPS fallback / auto-harvest on open.
    final locOk = await _ensureLocationPermission(showDeniedError: true);
    if (!locOk) {
      // Honest empty — do not auto-harvest around a stale Demo/Minsk prior.
      return;
    }
    await _applyRefreshPolicy(reason: 'open');
  }

  /// Runtime location prompt (in-app). Null [speedcamLocationProvider] = T1 desktop.
  Future<bool> _ensureLocationPermission({required bool showDeniedError}) async {
    final loc = ref.read(speedcamLocationProvider);
    if (loc == null) return true;
    final granted = await loc.ensurePermission();
    if (!granted) {
      if (showDeniedError && mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = l10n.speedcamLocationDenied;
          _busy = false;
          _policyNote = null;
        });
      }
      return false;
    }
    // Give native a beat to push lastKnown into the host pose.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return true;
  }

  Future<void> _reloadLocal() async {
    final store = ref.read(speedcamPackStoreProvider);
    final meta = await store.current(SpeedcamPackIds.by);
    final cams = await store.loadCams(SpeedcamPackIds.by);
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _allCams = cams;
      _sampleCams = cams.take(3).toList();
    });
  }

  Future<void> _applyRefreshPolicy({required String reason}) async {
    final sc = _speedcamCfg;
    if (sc.refreshPolicy != SpeedcamRefreshPolicy.ifStale) {
      if (!mounted) return;
      setState(() {
        _policyNote = 'Policy: manual only (no auto-refresh on $reason)';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _policyNote = 'Checking freshness…';
    });
    try {
      final locOk = await _ensureLocationPermission(showDeniedError: true);
      if (!locOk) return;
      final store = ref.read(speedcamPackStoreProvider);
      final before = await store.current(SpeedcamPackIds.by);
      final wasStale = before == null ||
          before.isStale(afterDays: sc.staleAfterDays);
      final center = _harvestCenter();
      final meta = await store.refreshIfNeeded(
        packId: SpeedcamPackIds.by,
        ifStale: true,
        staleAfterDays: sc.staleAfterDays,
        centerLat: center.lat,
        centerLon: center.lon,
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
        _allCams = cams;
        _sampleCams = cams.take(3).toList();
        _busy = false;
        if (refreshed) {
          _policyNote =
              'Auto-refreshed on $reason (was ${wasStale ? 'stale/missing' : 'updated'})';
        } else {
          _policyNote =
              'Pack fresh on $reason (< ${sc.staleAfterDays}d) — no fetch';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
        _policyNote = 'Auto-refresh failed on $reason';
      });
    }
  }


  ({double? lat, double? lon}) _harvestCenter() {
    final host = ref.read(speedcamServiceProvider).snapshot.host;
    if (host != null) return (lat: host.lat, lon: host.lon);
    return (lat: _meta?.centerLat, lon: _meta?.centerLon);
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
      _policyNote = null;
    });
    try {
      final locOk = await _ensureLocationPermission(showDeniedError: true);
      if (!locOk) return;
      final store = ref.read(speedcamPackStoreProvider);
      final center = _harvestCenter();
      // Permission ok but no live pose and no prior center → pack store StateError
      // (honest — no silent Minsk). Denied path never reaches here.
      final meta = await store.updatePack(
        SpeedcamPackIds.by,
        centerLat: center.lat,
        centerLon: center.lon,
      );
      await ref.read(speedcamServiceProvider).reloadFromPack();
      final cams = await store.loadCams(SpeedcamPackIds.by);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _allCams = cams;
        _sampleCams = cams.take(3).toList();
        _busy = false;
        _policyNote =
            'Harvest merged · ${meta.lastHarvestCount ?? meta.camCount} fetched · ${meta.camCount} in cache';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }


  Future<void> _startHudDemo() async {
    final svc = ref.read(speedcamServiceProvider);
    final cams = svc.snapshot.cams.isNotEmpty
        ? svc.snapshot.cams
        : FakeSpeedcamService.kFakeBySampleCams;
    // Prefer a cam with unknown facing so 0038 mute cannot hide the demo.
    final cam = cams.firstWhere(
      (c) => c.direction == null || c.direction!.trim().isEmpty,
      orElse: () => cams.first,
    );
    // 200 m south; heading null → facing filter fail-open (demo must show).
    final dLat = 200 / 111320.0;
    await svc.setHostPose(SpeedcamHostPose(
      lat: cam.lat - dLat,
      lon: cam.lon,
      speedKmh: 50,
    ));
    if (mounted) setState(() => _demoActive = true);
  }

  Future<void> _stopHudDemo() async {
    final svc = ref.read(speedcamServiceProvider);
    await svc.clearHostPose();
    if (mounted) setState(() => _demoActive = false);
  }

  Future<void> _patchSpeedcam(
    SpeedcamConfig Function(SpeedcamConfig) fn, {
    bool applyPolicy = false,
  }) async {
    final store = ref.read(configStoreProvider);
    final cfg = store.value;
    final next = fn(cfg.speedcam);
    await store.setConfig(cfg.copyWith(speedcam: next));
    if (applyPolicy && next.refreshPolicy == SpeedcamRefreshPolicy.ifStale) {
      await _applyRefreshPolicy(reason: 'policy-change');
    }
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
        key: const ValueKey('speedcam-settings-scroll'),
        padding: const EdgeInsets.all(16),
        children: [
          // DB + harvest FIRST (above the fold) — PDM/QA bar for 0037.
          SettingsSection(
            title: l10n.speedcamRadarSection,
            children: [
              // Cap disk to viewport so CRT is fully visible without scroll (0039).
              LayoutBuilder(
                builder: (context, constraints) {
                  final h = MediaQuery.sizeOf(context).height;
                  // App bar + toggles + range + section chrome ≈ 280; leave margin.
                  final maxH = (h - 280).clamp(160.0, 320.0);
                  // 220×300 plate (Maxim: rectangle, not square).
                  const plateAspect = 220.0 / 300.0;
                  final plateH = math.min(
                    constraints.maxWidth / plateAspect,
                    maxH,
                  );
                  final plateW = plateH * plateAspect;
                  final isAlien = sc.radarLook == SpeedcamRadarLook.alien;
                  // Rectangular CRT composite — painter fills bounds (0080).
                  // Real MediaQuery dpr + surface width drive alienDhuDpiBridge.
                  return Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: plateW,
                      height: plateH,
                      child: ColoredBox(
                        color: Colors.black,
                        child: SpeedcamRadarWidget(
                          variant: SpeedcamRadarVariant.dhuLarge,
                          alwaysShow: !isAlien,
                          forceDemoDanger: SpeedcamRadarWidget.demoDanger,
                          displayRadiusM: sc.dhuRangeM,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.speedcamHudMode,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<SpeedcamPresenceMode>(
                key: const ValueKey('speedcam-hud-mode'),
                segments: [
                  ButtonSegment(
                    value: SpeedcamPresenceMode.any,
                    label: Text(l10n.speedcamPresenceAny),
                  ),
                  ButtonSegment(
                    value: SpeedcamPresenceMode.dangerous,
                    label: Text(l10n.speedcamPresenceDangerous),
                  ),
                  ButtonSegment(
                    value: SpeedcamPresenceMode.off,
                    label: Text(l10n.speedcamPresenceOff),
                  ),
                ],
                selected: {sc.hudMode},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  _patchSpeedcam((c) => c.copyWith(hudMode: sel.first));
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('speedcam-ynavi-enrich'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamYnaviEnrich),
                subtitle: Text(l10n.speedcamYnaviEnrichHint),
                value: sc.ynaviEnrichEnabled,
                onChanged: (v) => _patchSpeedcam((c) => c.copyWith(ynaviEnrichEnabled: v)),
              ),
              if (sc.ynaviEnrichEnabled) ...[
                SwitchListTile(
                  key: const ValueKey('speedcam-ynavi-collect'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.speedcamYnaviCollect),
                  subtitle: Text(l10n.speedcamYnaviCollectHint),
                  value: sc.ynaviCollectEnabled,
                  onChanged: (v) =>
                      _patchSpeedcam((c) => c.copyWith(ynaviCollectEnabled: v)),
                ),
                SwitchListTile(
                  key: const ValueKey('speedcam-ynavi-alert'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.speedcamYnaviAlert),
                  subtitle: Text(l10n.speedcamYnaviAlertHint),
                  value: sc.ynaviAlertEnabled,
                  onChanged: (v) =>
                      _patchSpeedcam((c) => c.copyWith(ynaviAlertEnabled: v)),
                ),
                SettingsSlider(
                  label: l10n.speedcamYnaviAging,
                  valueLabel: '${sc.ynaviPointTtlDays}d',
                  minLabel: '1',
                  maxLabel: '30',
                  sliderKey: const ValueKey('speedcam-ynavi-ttl-days'),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  value: sc.ynaviPointTtlDays.toDouble().clamp(1, 30),
                  onChanged: (v) => _patchSpeedcam(
                    (c) => c.copyWith(ynaviPointTtlDays: v.round()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.speedcamYnaviAgingHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              SwitchListTile(
                key: const ValueKey('speedcam-dhu-system-overlay'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDhuSystemOverlay),
                subtitle: Text(l10n.speedcamDhuSystemOverlayHint),
                value: sc.dhuSystemOverlay,
                onChanged: (v) async {
                  if (v) {
                    final overlay = ref.read(speedcamSystemOverlayProvider);
                    final ok = await overlay.canDrawOverlays();
                    if (!ok) {
                      await overlay.openPermissionSettings();
                      final granted = await overlay.canDrawOverlays();
                      if (!granted) {
                        if (!mounted) return;
                        setState(() => _error = l10n.speedcamOverlayPermissionDenied);
                        return;
                      }
                    }
                  }
                  _patchSpeedcam((c) => c.copyWith(dhuSystemOverlay: v));
                },
              ),
              if (sc.dhuSystemOverlay) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.speedcamOverlaySize,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  key: const ValueKey('speedcam-overlay-size'),
                  value: sc.overlaySizeScale.clamp(0.6, 1.6),
                  min: 0.6,
                  max: 1.6,
                  divisions: 10,
                  label: '${sc.overlaySizeScale.toStringAsFixed(2)}×',
                  onChanged: (v) => _patchSpeedcam(
                    (c) => c.copyWith(overlaySizeScale: v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.speedcamOverlayPlacement,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<SpeedcamOverlayPlacement>(
                  key: const ValueKey('speedcam-overlay-placement'),
                  segments: [
                    ButtonSegment(
                      value: SpeedcamOverlayPlacement.topStart,
                      label: Text(l10n.speedcamOverlayTopStart),
                    ),
                    ButtonSegment(
                      value: SpeedcamOverlayPlacement.topEnd,
                      label: Text(l10n.speedcamOverlayTopEnd),
                    ),
                    ButtonSegment(
                      value: SpeedcamOverlayPlacement.bottomStart,
                      label: Text(l10n.speedcamOverlayBottomStart),
                    ),
                    ButtonSegment(
                      value: SpeedcamOverlayPlacement.bottomEnd,
                      label: Text(l10n.speedcamOverlayBottomEnd),
                    ),
                  ],
                  selected: {sc.overlayPlacement},
                  onSelectionChanged: (sel) {
                    if (sel.isEmpty) return;
                    _patchSpeedcam(
                      (c) => c.copyWith(overlayPlacement: sel.first),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.speedcamRadarLook,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<SpeedcamRadarLook>(
                key: const ValueKey('speedcam-radar-look'),
                segments: [
                  ButtonSegment(
                    value: SpeedcamRadarLook.defaultLook,
                    label: Text(l10n.speedcamRadarLookDefault),
                  ),
                  ButtonSegment(
                    value: SpeedcamRadarLook.alien,
                    label: Text(l10n.speedcamRadarLookAlien),
                  ),
                ],
                selected: {sc.radarLook},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  _patchSpeedcam((c) => c.copyWith(radarLook: sel.first));
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.speedcamSoundMode,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<SpeedcamPresenceMode>(
                key: const ValueKey('speedcam-sound-mode'),
                segments: [
                  ButtonSegment(
                    value: SpeedcamPresenceMode.any,
                    label: Text(l10n.speedcamPresenceAny),
                  ),
                  ButtonSegment(
                    value: SpeedcamPresenceMode.dangerous,
                    label: Text(l10n.speedcamPresenceDangerous),
                  ),
                  ButtonSegment(
                    value: SpeedcamPresenceMode.off,
                    label: Text(l10n.speedcamPresenceOff),
                  ),
                ],
                selected: {sc.soundMode},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  _patchSpeedcam((c) => c.copyWith(soundMode: sel.first));
                },
              ),
              SettingsSlider(
                label: l10n.speedcamSoundVolume,
                valueLabel: '${(sc.soundVolume * 100).round()}%',
                minLabel: '0',
                maxLabel: '100',
                sliderKey: const ValueKey('speedcam-sound-volume'),
                min: 0,
                max: 1,
                divisions: 20,
                value: sc.soundVolume.clamp(0.0, 1.0),
                onChanged: (v) => _patchSpeedcam(
                  (c) => c.copyWith(soundVolume: v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('speedcam-hud-demo'),
                      onPressed: _demoActive ? null : _startHudDemo,
                      child: Text(l10n.speedcamHudDemo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('speedcam-hud-demo-stop'),
                      onPressed: _demoActive ? _stopHudDemo : null,
                      child: Text(l10n.speedcamHudDemoStop),
                    ),
                  ),
                ],
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
          ),          SettingsSection(
            title: l10n.speedcamDbSection,
            children: [
              SpeedcamPackMapPreview(
                cams: _allCams,
                meta: meta,
                hostPose: ref.watch(speedcamSnapshotProvider).host,
                expandTooltip: l10n.speedcamMapExpand,
                collapseTooltip: l10n.speedcamMapCollapse,
                myLocationTooltip: l10n.speedcamMapMyLocation,
                noLocationMessage: l10n.speedcamMapNoLocation,
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const ValueKey('speedcam-db-coverage'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.speedcamDbCoverage),
                subtitle: Text(
                  meta == null
                      ? l10n.speedcamPackMissing
                      : meta.coverageLabel,
                ),
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
              Builder(
                builder: (context) {
                  final svc = ref.watch(speedcamServiceProvider);
                  final osm = svc is DefaultSpeedcamService
                      ? svc.osmCamCount
                      : _allCams
                          .where((c) =>
                              !c.id.startsWith('ynavi:') && c.source != 'ynavi')
                          .length;
                  final ynavi = svc is DefaultSpeedcamService
                      ? svc.ynaviCamCount
                      : _allCams.where((c) => c.isYnaviSourced).length;
                  return ListTile(
                    key: const ValueKey('speedcam-osm-ynavi-counts'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.speedcamOsmYnaviCounts(osm, ynavi)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.speedcamHarvestSection,
            children: [
              Text(
                l10n.speedcamRefreshPolicy,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
                  _patchSpeedcam(
                    (c) => c.copyWith(refreshPolicy: sel.first),
                    applyPolicy: true,
                  );
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
                  child: Text(
                    _policyNote!,
                    key: const ValueKey('speedcam-policy-note'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
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
          if (_sampleCams.isNotEmpty) ...[
            const SizedBox(height: 16),
            SettingsSection(
              title: l10n.speedcamDbSample,
              children: [
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
            ),
          ],
          const SizedBox(height: 16),

        ],
      ),
    );
  }
}

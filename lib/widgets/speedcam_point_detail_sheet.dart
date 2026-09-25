import 'package:flutter/material.dart';

import '../services/speedcam.dart';

/// Glance label for pack / enrich origin.
String speedcamSourceLabel(String? source) {
  switch (source) {
    case 'osm+ynavi':
      return 'osm+ynavi (merged)';
    case 'ynavi':
      return 'ynavi';
    case 'overpass':
      return 'overpass (OSM)';
    case null:
    case '':
      return 'legacy OSM (source unset)';
    default:
      return source;
  }
}

/// Field-level OSM↔YNavi contribution notes (merge rules in
/// [DefaultSpeedcamService.mergeOsmWithYnavi]).
List<MapEntry<String, String>> speedcamFieldProvenance(SpeedcamPoint cam) {
  final source = cam.source;
  if (source == 'osm+ynavi') {
    return const [
      MapEntry('id / lat / lon', 'OSM (YNavi match claimed ~≤20 m)'),
      MapEntry('direction', 'OSM only (YNavi has no facing)'),
      MapEntry(
        'camType',
        'YNavi LANE/other-traffic camType stamped when isOtherTrafficCam (0092/0102); else OSM',
      ),
      MapEntry('maxspeed', 'OSM if set, else YNavi'),
      MapEntry('lastSeenEpochMs', 'YNavi overlay'),
      MapEntry('source', 'stamped osm+ynavi'),
    ];
  }
  if (source == 'ynavi' || cam.id.startsWith('ynavi:')) {
    return const [
      MapEntry('id / lat / lon / maxspeed / camType', 'YNavi SPEEDCAM_DATA'),
      MapEntry('direction', 'always null (bridge has no facing)'),
      MapEntry('lastSeenEpochMs', 'YNavi t_ms / ingest wall clock'),
      MapEntry('source', 'ynavi'),
    ];
  }
  return const [
    MapEntry('id / lat / lon / maxspeed / direction', 'OSM Overpass pack'),
    MapEntry('camType / lastSeenEpochMs', 'usually unset on pure OSM'),
    MapEntry('source', 'overpass or legacy unset'),
  ];
}

/// Opens a scrollable bottom sheet with the full stored [SpeedcamPoint].
Future<void> showSpeedcamPointDetailSheet(
  BuildContext context,
  SpeedcamPoint cam,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SpeedcamPointDetailSheet(cam: cam),
  );
}

/// Full cam metadata panel (map marker / DB sample tap → 0093).
class SpeedcamPointDetailSheet extends StatelessWidget {
  const SpeedcamPointDetailSheet({super.key, required this.cam});

  final SpeedcamPoint cam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <MapEntry<String, String>>[
      MapEntry('id', cam.id),
      MapEntry('lat', cam.lat.toString()),
      MapEntry('lon', cam.lon.toString()),
      MapEntry('maxspeed', cam.maxspeed?.toString() ?? '—'),
      MapEntry('direction', cam.direction ?? '—'),
      MapEntry('source', speedcamSourceLabel(cam.source)),
      MapEntry('camType', cam.camType ?? '—'),
      MapEntry(
        'lastSeen',
        cam.lastSeenEpochMs == null
            ? '—'
            : DateTime.fromMillisecondsSinceEpoch(
                cam.lastSeenEpochMs!,
                isUtc: false,
              ).toIso8601String(),
      ),
      MapEntry('lastSeenEpochMs', cam.lastSeenEpochMs?.toString() ?? '—'),
      MapEntry('isYnaviSourced', cam.isYnaviSourced.toString()),
      MapEntry('isLaneCam', isLaneCam(cam).toString()),
      MapEntry('isOtherTrafficCam', isOtherTrafficCam(cam).toString()),
    ];

    final provenance = speedcamFieldProvenance(cam);

    return SafeArea(
      key: const ValueKey('speedcam-cam-detail'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text(
                'Speedcam metadata',
                key: const ValueKey('speedcam-cam-detail-title'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                speedcamSourceLabel(cam.source),
                key: const ValueKey('speedcam-cam-detail-source-badge'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                _MetaRow(
                  label: row.key,
                  value: row.value,
                  valueKey: ValueKey('speedcam-cam-detail-${row.key}'),
                ),
              const SizedBox(height: 12),
              Text(
                'Merge provenance (OSM ↔ YNavi)',
                key: const ValueKey('speedcam-cam-detail-provenance-title'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final p in provenance)
                _MetaRow(
                  label: p.key,
                  value: p.value,
                  dense: true,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('speedcam-cam-detail-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.dense = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: dense ? 140 : 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marker fill by enrich origin — glanceable on the pack map.
Color speedcamMarkerColor(String? source) {
  switch (source) {
    case 'osm+ynavi':
      return const Color(0xFFFFB300); // amber — merged
    case 'ynavi':
      return const Color(0xFF7C4DFF); // purple — pure YNavi
    default:
      return const Color(0xFFFF6B4A); // coral — OSM / overpass / legacy
  }
}

/// Prefer one merged + one OSM + one YNavi when present (0093 sample strip).
List<SpeedcamPoint> pickSpeedcamSampleCams(List<SpeedcamPoint> cams, {int max = 3}) {
  if (cams.isEmpty || max <= 0) return const [];
  SpeedcamPoint? merged;
  SpeedcamPoint? osm;
  SpeedcamPoint? ynavi;
  for (final c in cams) {
    final s = c.source;
    if (merged == null && s == 'osm+ynavi') {
      merged = c;
    } else if (ynavi == null && (s == 'ynavi' || c.id.startsWith('ynavi:'))) {
      ynavi = c;
    } else if (osm == null && s != 'ynavi' && s != 'osm+ynavi') {
      osm = c;
    }
    if (merged != null && osm != null && ynavi != null) break;
  }
  final out = <SpeedcamPoint>[
    ?merged,
    ?osm,
    ?ynavi,
  ];
  if (out.length >= max) return out.take(max).toList();
  for (final c in cams) {
    if (out.any((x) => x.id == c.id)) continue;
    out.add(c);
    if (out.length >= max) break;
  }
  return out;
}

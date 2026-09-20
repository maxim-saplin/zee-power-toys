import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';

/// DHU OSM map preview of cached pack cams.
///
/// Real OpenStreetMap tiles via [flutter_map]. Dense packs are downsampled
/// (≤ [kMaxMarkers]) so the DHU stays smooth. ODbL credit lives in Speedcam
/// settings; the map shows the standard OSM tile attribution chip.
class SpeedcamPackMapPreview extends StatelessWidget {
  const SpeedcamPackMapPreview({
    super.key,
    required this.cams,
    this.meta,
    this.height = 240,
    @visibleForTesting this.tileProvider,
  });

  final List<SpeedcamPoint> cams;
  final SpeedcamPackMeta? meta;
  final double height;

  /// Optional override so widget tests skip network tile fetches.
  @visibleForTesting
  final TileProvider? tileProvider;

  static const int kMaxMarkers = 400;

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _userAgentPackage = 'com.zeepowertoys.zee_power_toys';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = cams.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('speedcam-pack-map'),
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: empty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No cameras cached — harvest to preview',
                          key: const ValueKey('speedcam-pack-map-empty'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ),
                    )
                  : _buildMap(context, scheme),
            ),
          ),
        ),
        if (!empty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _caption(cams.length, meta),
              key: const ValueKey('speedcam-pack-map-caption'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildMap(BuildContext context, ColorScheme scheme) {
    final shown = _downsample(cams, kMaxMarkers);
    final bounds = _fitBounds(shown, meta);
    final accent = scheme.primary;
    final centerLat = meta?.centerLat;
    final centerLon = meta?.centerLon;
    final radiusKm = meta?.radiusKm ?? kSpeedcamHarvestRadiusKm;
    final dotR = shown.length > 200 ? 2.0 : (shown.length > 80 ? 2.5 : 3.5);

    final circles = <CircleMarker>[
      if (centerLat != null && centerLon != null) ...[
        CircleMarker(
          point: LatLng(centerLat, centerLon),
          radius: radiusKm * 1000,
          useRadiusInMeter: true,
          color: accent.withValues(alpha: 0.12),
          borderStrokeWidth: 1.5,
          borderColor: accent.withValues(alpha: 0.5),
        ),
        CircleMarker(
          point: LatLng(centerLat, centerLon),
          radius: 4,
          color: accent,
        ),
      ],
      for (final cam in shown)
        CircleMarker(
          point: LatLng(cam.lat, cam.lon),
          radius: dotR,
          color: const Color(0xFFFF6B4A),
        ),
    ];

    return FlutterMap(
      // Remount when pack data changes so [initialCameraFit] re-applies.
      key: ValueKey(
        'pack-map-${cams.length}-'
        '${meta?.centerLat}-${meta?.centerLon}-${meta?.radiusKm}',
      ),
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(18),
          maxZoom: 14,
        ),
        backgroundColor: Colors.black,
        interactionOptions: const InteractionOptions(
          // Pan / pinch-zoom OK on DHU; rotation is awkward at 240px height.
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _osmTileUrl,
          userAgentPackageName: _userAgentPackage,
          maxNativeZoom: 19,
          tileProvider: tileProvider,
        ),
        CircleLayer(circles: circles),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
      ],
    );
  }

  static String _caption(int n, SpeedcamPackMeta? meta) {
    final coverage = meta?.coverageLabel ?? 'within 300 km';
    final shown = n > kMaxMarkers ? ' · showing $kMaxMarkers' : '';
    return '$n cameras · $coverage$shown';
  }

  /// Bounds from cam markers, expanded by harvest center/radius when known.
  static LatLngBounds _fitBounds(
    List<SpeedcamPoint> cams,
    SpeedcamPackMeta? meta,
  ) {
    final points = <LatLng>[
      for (final c in cams) LatLng(c.lat, c.lon),
    ];
    final centerLat = meta?.centerLat;
    final centerLon = meta?.centerLon;
    if (centerLat != null && centerLon != null) {
      final r = meta?.radiusKm ?? kSpeedcamHarvestRadiusKm;
      final dLat = r / 111.0;
      final cosLat =
          math.cos(centerLat * math.pi / 180).abs().clamp(0.2, 1.0);
      final dLon = r / (111.0 * cosLat);
      points.add(LatLng(centerLat - dLat, centerLon - dLon));
      points.add(LatLng(centerLat + dLat, centerLon + dLon));
    }
    // Degenerate single-point packs: nudge so CameraFit has a span.
    if (points.length == 1) {
      final p = points.first;
      points.add(LatLng(p.latitude + 0.05, p.longitude + 0.05));
      points.add(LatLng(p.latitude - 0.05, p.longitude - 0.05));
    }
    return LatLngBounds.fromPoints(points);
  }

  /// Grid-bucket downsample — keeps spatial spread for large packs.
  static List<SpeedcamPoint> _downsample(List<SpeedcamPoint> cams, int max) {
    if (cams.length <= max) return cams;
    var minLat = cams.first.lat;
    var maxLat = cams.first.lat;
    var minLon = cams.first.lon;
    var maxLon = cams.first.lon;
    for (final c in cams) {
      minLat = math.min(minLat, c.lat);
      maxLat = math.max(maxLat, c.lat);
      minLon = math.min(minLon, c.lon);
      maxLon = math.max(maxLon, c.lon);
    }
    final cells = math.max(8, math.sqrt(max).ceil());
    final dLat = math.max(1e-9, (maxLat - minLat) / cells);
    final dLon = math.max(1e-9, (maxLon - minLon) / cells);
    final buckets = <String, SpeedcamPoint>{};
    for (final c in cams) {
      final i = ((c.lat - minLat) / dLat).floor().clamp(0, cells - 1);
      final j = ((c.lon - minLon) / dLon).floor().clamp(0, cells - 1);
      buckets.putIfAbsent('$i:$j', () => c);
      if (buckets.length >= max) break;
    }
    return buckets.values.toList();
  }
}

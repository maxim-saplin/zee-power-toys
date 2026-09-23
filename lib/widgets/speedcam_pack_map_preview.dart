import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';
import 'speedcam_point_detail_sheet.dart';

/// DHU OSM map preview of cached pack cams.
///
/// Real OpenStreetMap tiles via [flutter_map]. Packs above [kMaxMarkers]
/// (~2000) are downsampled so the DHU stays smooth; typical ≤2000 packs
/// paint all markers. ODbL credit lives in Speedcam settings; the map shows
/// the standard OSM tile attribution chip.
///
/// 0075: expand/collapse + go-to-my-location (host pose; fail loud if none).
class SpeedcamPackMapPreview extends StatefulWidget {
  const SpeedcamPackMapPreview({
    super.key,
    required this.cams,
    this.meta,
    this.height = 240,
    this.expandedHeight = 480,
    this.hostPose,
    this.expandTooltip = 'Expand map',
    this.collapseTooltip = 'Collapse map',
    this.myLocationTooltip = 'Go to my location',
    this.noLocationMessage = 'No location fix yet',
    @visibleForTesting this.tileProvider,
  });

  final List<SpeedcamPoint> cams;
  final SpeedcamPackMeta? meta;
  final double height;
  final double expandedHeight;

  /// Live host pose for recenter + optional blue pin. Null → my-loc fails loud.
  final SpeedcamHostPose? hostPose;

  final String expandTooltip;
  final String collapseTooltip;
  final String myLocationTooltip;
  final String noLocationMessage;

  /// Optional override so widget tests skip network tile fetches.
  @visibleForTesting
  final TileProvider? tileProvider;

  /// High enough that typical harvests (≤~2000 cams) paint every marker (0052).
  static const int kMaxMarkers = 2000;

  /// Visible cam-dot radius in logical px (0100).
  ///
  /// Pack density sets a base; zoom scales it up when zoomed in so fat-finger
  /// taps stay easy while scrolling. Soft caps keep dense packs readable
  /// (clustering is 0101 — not here).
  @visibleForTesting
  static double camDotRadius({
    required int shownCount,
    required double zoom,
  }) {
    final base = shownCount > 200 ? 3.0 : (shownCount > 80 ? 4.0 : 5.0);
    // Ref zoom 11 ≈ fit for larger packs; ~+12% per zoom level, clamped.
    final scale = (1.0 + (zoom - 11.0) * 0.12).clamp(0.85, 1.7);
    return (base * scale).clamp(2.5, 9.0);
  }

  /// Marker hit-target extent (width/height) for [camDotRadius] (0100).
  @visibleForTesting
  static double camHitExtent(double dotR) =>
      (dotR * 2 + 18).clamp(28.0, 44.0);

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _userAgentPackage = 'com.zeepowertoys.zee_power_toys';

  @override
  State<SpeedcamPackMapPreview> createState() => _SpeedcamPackMapPreviewState();
}

class _SpeedcamPackMapPreviewState extends State<SpeedcamPackMapPreview> {
  MapController _mapController = MapController();
  bool _expanded = false;

  /// Quantized map zoom for cam-dot sizing (0100). Null until first camera report.
  double? _zoom;

  double get _mapHeight =>
      _expanded ? widget.expandedHeight : widget.height;

  static double _quantizeZoom(double zoom) => (zoom * 4).round() / 4.0;

  void _onCameraZoom(double zoom) {
    final q = _quantizeZoom(zoom);
    if (_zoom == q) return;
    setState(() => _zoom = q);
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      _zoom = null; // remount picks up fit zoom via onMapReady
      // Fresh controller — reuse across size remounts trips flutter_map assert.
      _mapController = MapController();
    });
  }

  void _goMyLocation() {
    final pose = widget.hostPose;
    if (pose == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          key: const ValueKey('speedcam-pack-map-no-location'),
          content: Text(widget.noLocationMessage),
        ),
      );
      return;
    }
    _mapController.move(LatLng(pose.lat, pose.lon), 13);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = widget.cams.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: ValueKey('speedcam-pack-map-${_expanded ? 'expanded' : 'collapsed'}'),
          height: _mapHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: empty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No cameras cached — harvest to preview',
                                key: const ValueKey('speedcam-pack-map-empty'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ),
                          )
                        : _buildMap(context, scheme),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        Material(
                          color: scheme.surface.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey('speedcam-pack-map-expand'),
                            tooltip: _expanded
                                ? widget.collapseTooltip
                                : widget.expandTooltip,
                            icon: Icon(
                              _expanded
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                            ),
                            onPressed: _toggleExpand,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: scheme.surface.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey('speedcam-pack-map-myloc'),
                            tooltip: widget.myLocationTooltip,
                            icon: const Icon(Icons.my_location),
                            onPressed: _goMyLocation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!empty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _caption(widget.cams.length, widget.meta),
              key: const ValueKey('speedcam-pack-map-caption'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildMap(BuildContext context, ColorScheme scheme) {
    final shown = _downsample(widget.cams, SpeedcamPackMapPreview.kMaxMarkers);
    final bounds = _fitBounds(shown, widget.meta);
    final accent = scheme.primary;
    final centerLat = widget.meta?.centerLat;
    final centerLon = widget.meta?.centerLon;
    final radiusKm = widget.meta?.radiusKm ?? kSpeedcamHarvestRadiusKm;
    // 0100: larger visible + hit; zoom-aware (grow when zoomed in).
    final zoom = _zoom ?? 12.0;
    final dotR = SpeedcamPackMapPreview.camDotRadius(
      shownCount: shown.length,
      zoom: zoom,
    );
    final hit = SpeedcamPackMapPreview.camHitExtent(dotR);
    final pose = widget.hostPose;

    // Harvest radius + host pin stay circles; cams are Markers so they tap.
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
      if (pose != null)
        CircleMarker(
          point: LatLng(pose.lat, pose.lon),
          radius: 6,
          color: const Color(0xFF4FC3F7),
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
    ];

    final markers = <Marker>[
      for (final cam in shown)
        Marker(
          key: ValueKey('speedcam-cam-marker-${cam.id}'),
          point: LatLng(cam.lat, cam.lon),
          width: hit,
          height: hit,
          child: GestureDetector(
            key: ValueKey('speedcam-cam-tap-${cam.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showSpeedcamPointDetailSheet(context, cam),
            child: Center(
              child: Container(
                width: dotR * 2,
                height: dotR * 2,
                decoration: BoxDecoration(
                  color: speedcamMarkerColor(cam.source),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      // Remount when pack data changes so [initialCameraFit] re-applies.
      key: ValueKey(
        'pack-map-${_expanded ? 'x' : 'c'}-${widget.cams.length}-'
        '${widget.meta?.centerLat}-${widget.meta?.centerLon}-${widget.meta?.radiusKm}',
      ),
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(18),
          maxZoom: 14,
        ),
        backgroundColor: Colors.black,
        interactionOptions: const InteractionOptions(
          // Pan / pinch-zoom OK on DHU; rotation is awkward at compact height.
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          if (!mounted) return;
          _onCameraZoom(_mapController.camera.zoom);
        },
        onPositionChanged: (camera, _) {
          if (!mounted) return;
          _onCameraZoom(camera.zoom);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: SpeedcamPackMapPreview._osmTileUrl,
          userAgentPackageName: SpeedcamPackMapPreview._userAgentPackage,
          maxNativeZoom: 19,
          tileProvider: widget.tileProvider,
        ),
        CircleLayer(circles: circles),
        MarkerLayer(markers: markers),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
      ],
    );
  }

  static String _caption(int n, SpeedcamPackMeta? meta) {
    final coverage = meta?.coverageLabel ?? 'within 300 km';
    // Only mention a cap when we actually downsample — never "showing 400"
    // for a ~574 pack (0052).
    final shown = n > SpeedcamPackMapPreview.kMaxMarkers
        ? ' · showing ${SpeedcamPackMapPreview.kMaxMarkers}'
        : '';
    return '$n cameras · $coverage$shown';
  }

  /// Bounds from cam markers (+ harvest center pin). Does **not** expand to the
  /// full 300 km circle — that left the map mostly empty for modest packs
  /// (0052). The radius circle still draws as an overlay; users can zoom out.
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
      points.add(LatLng(centerLat, centerLon));
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

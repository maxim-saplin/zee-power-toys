import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';
import 'speedcam_point_detail_sheet.dart';

/// One paint node on the pack map: a single cam or a zoom-grid cluster (0101).
@visibleForTesting
class SpeedcamMapNode {
  const SpeedcamMapNode({
    required this.cams,
    required this.lat,
    required this.lon,
  });

  final List<SpeedcamPoint> cams;
  final double lat;
  final double lon;

  bool get isCluster => cams.length > 1;
  int get count => cams.length;

  SpeedcamPoint get primary => cams.first;

  factory SpeedcamMapNode.fromCams(List<SpeedcamPoint> cams) {
    assert(cams.isNotEmpty);
    if (cams.length == 1) {
      final c = cams.first;
      return SpeedcamMapNode(cams: cams, lat: c.lat, lon: c.lon);
    }
    var lat = 0.0;
    var lon = 0.0;
    for (final c in cams) {
      lat += c.lat;
      lon += c.lon;
    }
    final n = cams.length.toDouble();
    return SpeedcamMapNode(cams: cams, lat: lat / n, lon: lon / n);
  }
}

/// DHU OSM map preview of cached pack cams.
///
/// Real OpenStreetMap tiles via [flutter_map]. Zoom-scaled grid clustering
/// (0101) keeps zoomed-out packs readable without a cluster plugin; typical
/// packs paint every cam when zoomed in. Soft [kMaxMarkers] is a layer-item
/// safety cap only. ODbL credit lives in Speedcam settings; the map shows
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

  /// Soft cap on painted layer items (clusters + singles) after viewport filter
  /// + grid cluster. Prefer widening the grid over dropping cams (0101).
  static const int kMaxMarkers = 2000;

  /// Default cluster radius in screen px → geographic cell size at [zoom].
  @visibleForTesting
  static const double kClusterRadiusPx = 52;

  /// Visible cam-dot radius in logical px (0100).
  ///
  /// Pack density sets a base; zoom scales it up when zoomed in so fat-finger
  /// taps stay easy while scrolling. Soft caps keep dense packs readable;
  /// zoom-out density is handled by clustering (0101).
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

  /// Geographic cell size (degrees) for [zoom] at [radiusPx] screen radius.
  @visibleForTesting
  static double clusterCellDegrees(
    double zoom, {
    double radiusPx = kClusterRadiusPx,
  }) {
    final worldPx = 256.0 * math.pow(2.0, zoom.clamp(1.0, 20.0));
    return math.max(1e-6, (360.0 / worldPx) * radiusPx);
  }

  /// Zoom-grid cluster: nearby cams merge at low zoom, split when zoomed in.
  @visibleForTesting
  static List<SpeedcamMapNode> clusterCams(
    List<SpeedcamPoint> cams,
    double zoom, {
    double radiusPx = kClusterRadiusPx,
    int maxNodes = kMaxMarkers,
  }) {
    if (cams.isEmpty) return const [];
    var radius = radiusPx;
    for (var attempt = 0; attempt < 8; attempt++) {
      final cell = clusterCellDegrees(zoom, radiusPx: radius);
      final buckets = <String, List<SpeedcamPoint>>{};
      for (final c in cams) {
        final i = (c.lat / cell).floor();
        final j = (c.lon / cell).floor();
        buckets.putIfAbsent('$i:$j', () => <SpeedcamPoint>[]).add(c);
      }
      if (buckets.length <= maxNodes || attempt == 7) {
        return [
          for (final group in buckets.values) SpeedcamMapNode.fromCams(group),
        ];
      }
      radius *= 1.55;
    }
    return const [];
  }

  /// Keep cams inside [bounds] (+ fractional pad) so high-zoom layers stay light.
  @visibleForTesting
  static List<SpeedcamPoint> camsInBounds(
    List<SpeedcamPoint> cams,
    LatLngBounds bounds, {
    double padFrac = 0.2,
  }) {
    final latSpan = (bounds.north - bounds.south).abs();
    final lonSpan = (bounds.east - bounds.west).abs();
    final latPad = math.max(latSpan * padFrac, 1e-4);
    final lonPad = math.max(lonSpan * padFrac, 1e-4);
    final n = bounds.north + latPad;
    final s = bounds.south - latPad;
    final e = bounds.east + lonPad;
    final w = bounds.west - lonPad;
    return [
      for (final c in cams)
        if (c.lat <= n && c.lat >= s && c.lon <= e && c.lon >= w) c,
    ];
  }

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _userAgentPackage = 'com.zeepowertoys.zee_power_toys';

  @override
  State<SpeedcamPackMapPreview> createState() => _SpeedcamPackMapPreviewState();
}

class _SpeedcamPackMapPreviewState extends State<SpeedcamPackMapPreview> {
  MapController _mapController = MapController();
  bool _expanded = false;
  bool _mapReady = false;

  /// Quantized map zoom for cam-dot sizing (0100) + clustering (0101).
  double? _zoom;

  /// Coarse view-bounds key so pan does not rebuild every pixel.
  String? _viewKey;
  LatLngBounds? _viewBounds;

  double get _mapHeight =>
      _expanded ? widget.expandedHeight : widget.height;

  static double _quantizeZoom(double zoom) => (zoom * 4).round() / 4.0;

  static String _boundsKey(LatLngBounds b) {
    String q(double v) => (v * 50).round().toString(); // ~0.02°
    return '${q(b.south)}:${q(b.west)}:${q(b.north)}:${q(b.east)}';
  }

  void _syncCamera(MapCamera camera) {
    final q = _quantizeZoom(camera.zoom);
    final key = _boundsKey(camera.visibleBounds);
    if (_zoom == q && _viewKey == key && _mapReady) return;
    setState(() {
      _zoom = q;
      _viewKey = key;
      _viewBounds = camera.visibleBounds;
      _mapReady = true;
    });
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      _zoom = null;
      _viewKey = null;
      _viewBounds = null;
      _mapReady = false;
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

  void _onClusterTap(SpeedcamMapNode node) {
    if (!node.isCluster) {
      showSpeedcamPointDetailSheet(context, node.primary);
      return;
    }
    final points = [for (final c in node.cams) LatLng(c.lat, c.lon)];
    // Degenerate / tiny clusters: nudge so CameraFit has a span, then cap zoom.
    if (points.length == 1) {
      final p = points.first;
      points.add(LatLng(p.latitude + 0.01, p.longitude + 0.01));
      points.add(LatLng(p.latitude - 0.01, p.longitude - 0.01));
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(36),
        maxZoom: 16,
      ),
    );
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
    final zoom = _zoom ?? 12.0;
    // Before first camera report, cluster the full pack at assumed fit zoom.
    // After ready, viewport-filter so high zoom does not build thousands of
    // off-screen Marker widgets (T2 / full 300 km pack).
    final sourceCams = (_mapReady && _viewBounds != null)
        ? SpeedcamPackMapPreview.camsInBounds(widget.cams, _viewBounds!)
        : widget.cams;
    final nodes = SpeedcamPackMapPreview.clusterCams(sourceCams, zoom);
    final bounds = _fitBounds(widget.cams, widget.meta);
    final accent = scheme.primary;
    final centerLat = widget.meta?.centerLat;
    final centerLon = widget.meta?.centerLon;
    final radiusKm = widget.meta?.radiusKm ?? kSpeedcamHarvestRadiusKm;
    // 0100: larger visible + hit; zoom-aware (grow when zoomed in).
    // Density base uses full pack size (not viewport slice).
    final dotR = SpeedcamPackMapPreview.camDotRadius(
      shownCount: widget.cams.length,
      zoom: zoom,
    );
    final hit = SpeedcamPackMapPreview.camHitExtent(dotR);
    final pose = widget.hostPose;

    // Harvest radius + host pin stay circles; cams/clusters are Markers so they tap.
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
      for (final node in nodes)
        if (node.isCluster)
          Marker(
            key: ValueKey(
              'speedcam-cluster-${node.count}-'
              '${node.lat.toStringAsFixed(4)}-${node.lon.toStringAsFixed(4)}',
            ),
            point: LatLng(node.lat, node.lon),
            width: _clusterExtent(node.count),
            height: _clusterExtent(node.count),
            child: GestureDetector(
              key: ValueKey(
                'speedcam-cluster-tap-${node.count}-'
                '${node.lat.toStringAsFixed(4)}-${node.lon.toStringAsFixed(4)}',
              ),
              behavior: HitTestBehavior.opaque,
              onTap: () => _onClusterTap(node),
              child: _ClusterBubble(
                count: node.count,
                color: accent,
              ),
            ),
          )
        else
          Marker(
            key: ValueKey('speedcam-cam-marker-${node.primary.id}'),
            point: LatLng(node.lat, node.lon),
            width: hit,
            height: hit,
            child: GestureDetector(
              key: ValueKey('speedcam-cam-tap-${node.primary.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showSpeedcamPointDetailSheet(context, node.primary),
              child: Center(
                child: Container(
                  width: dotR * 2,
                  height: dotR * 2,
                  decoration: BoxDecoration(
                    color: speedcamMarkerColor(node.primary.source),
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
          _syncCamera(_mapController.camera);
        },
        onPositionChanged: (camera, _) {
          if (!mounted) return;
          _syncCamera(camera);
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

  static double _clusterExtent(int count) {
    if (count >= 100) return 44;
    if (count >= 20) return 40;
    return 36;
  }

  static String _caption(int n, SpeedcamPackMeta? meta) {
    final coverage = meta?.coverageLabel ?? 'within 300 km';
    // Clustering aggregates — caption always shows the full pack count.
    return '$n cameras · $coverage';
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
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : '$count';
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

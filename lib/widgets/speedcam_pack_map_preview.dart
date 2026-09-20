import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';

/// DHU map-like preview of cached pack cams (0046).
///
/// Lightweight CustomPaint — no flutter_map dep. Downsamples dense sets so
/// hundreds of markers stay smooth at DHU scale.
class SpeedcamPackMapPreview extends StatelessWidget {
  const SpeedcamPackMapPreview({
    super.key,
    required this.cams,
    this.meta,
    this.height = 200,
  });

  final List<SpeedcamPoint> cams;
  final SpeedcamPackMeta? meta;
  final double height;

  static const int kMaxMarkers = 400;

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
                  : CustomPaint(
                      painter: _PackMapPainter(
                        cams: _downsample(cams, kMaxMarkers),
                        totalCount: cams.length,
                        centerLat: meta?.centerLat,
                        centerLon: meta?.centerLon,
                        radiusKm: meta?.radiusKm ?? kSpeedcamHarvestRadiusKm,
                        accent: scheme.primary,
                        dim: scheme.onSurface.withValues(alpha: 0.35),
                      ),
                      child: const SizedBox.expand(),
                    ),
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

  static String _caption(int n, SpeedcamPackMeta? meta) {
    final coverage = meta?.coverageLabel ?? 'within 300 km';
    final shown = n > kMaxMarkers ? ' · showing $kMaxMarkers' : '';
    return '$n cameras · $coverage$shown';
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

class _PackMapPainter extends CustomPainter {
  _PackMapPainter({
    required this.cams,
    required this.totalCount,
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.accent,
    required this.dim,
  });

  final List<SpeedcamPoint> cams;
  final int totalCount;
  final double? centerLat;
  final double? centerLon;
  final double radiusKm;
  final Color accent;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0 || cams.isEmpty) return;

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
    // Include harvest center / radius hint in bounds when known.
    if (centerLat != null && centerLon != null) {
      final dLat = radiusKm / 111.0;
      final cosLat = math.cos(centerLat! * math.pi / 180).abs().clamp(0.2, 1.0);
      final dLon = radiusKm / (111.0 * cosLat);
      minLat = math.min(minLat, centerLat! - dLat);
      maxLat = math.max(maxLat, centerLat! + dLat);
      minLon = math.min(minLon, centerLon! - dLon);
      maxLon = math.max(maxLon, centerLon! + dLon);
    }
    // Pad bounds so edge markers aren't clipped.
    final latPad = math.max(0.02, (maxLat - minLat) * 0.08);
    final lonPad = math.max(0.02, (maxLon - minLon) * 0.08);
    minLat -= latPad;
    maxLat += latPad;
    minLon -= lonPad;
    maxLon += lonPad;

    final latSpan = math.max(1e-6, maxLat - minLat);
    final lonSpan = math.max(1e-6, maxLon - minLon);

    Offset project(double lat, double lon) {
      final x = pad + ((lon - minLon) / lonSpan) * w;
      final y = pad + ((maxLat - lat) / latSpan) * h; // north-up
      return Offset(x, y);
    }

    // Grid
    final grid = Paint()
      ..color = dim
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final x = pad + w * i / 4;
      final y = pad + h * i / 4;
      canvas.drawLine(Offset(x, pad), Offset(x, pad + h), grid);
      canvas.drawLine(Offset(pad, y), Offset(pad + w, y), grid);
    }

    // Harvest radius circle (approx equirectangular)
    if (centerLat != null && centerLon != null) {
      final c = project(centerLat!, centerLon!);
      final edge = project(centerLat! + radiusKm / 111.0, centerLon!);
      final r = (c.dy - edge.dy).abs();
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = accent.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(c, 3.5, Paint()..color = accent);
    }

    final dot = Paint()..color = const Color(0xFFFF6B4A);
    final r = cams.length > 200 ? 1.8 : (cams.length > 80 ? 2.4 : 3.2);
    for (final cam in cams) {
      canvas.drawCircle(project(cam.lat, cam.lon), r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PackMapPainter old) =>
      old.cams != cams ||
      old.centerLat != centerLat ||
      old.centerLon != centerLon ||
      old.radiusKm != radiusKm ||
      old.totalCount != totalCount;
}

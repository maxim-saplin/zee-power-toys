import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/widgets/speedcam_pack_map_preview.dart';
import 'package:zee_power_toys/widgets/speedcam_point_detail_sheet.dart';

/// 1×1 transparent PNG — avoids network tile fetches in widget tests.
final Uint8List _kTinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_kTinyPng);
}

void main() {
  final fakeTiles = _FakeTileProvider();

  testWidgets('empty state is honest', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(cams: []),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('speedcam-pack-map-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-pack-map-caption')), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('speedcam-pack-map-expand')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-pack-map-myloc')), findsOneWidget);
  });

  testWidgets('expand toggles map height key', (tester) async {
    final cams = [
      for (var i = 0; i < 3; i++)
        SpeedcamPoint(id: 'c$i', lat: 53.9 + i * 0.01, lon: 27.5 + i * 0.01),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('speedcam-pack-map-collapsed')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speedcam-pack-map-expand')));
    await tester.pump();
    expect(find.byKey(const ValueKey('speedcam-pack-map-expanded')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speedcam-pack-map-expand')));
    await tester.pump();
    expect(find.byKey(const ValueKey('speedcam-pack-map-collapsed')), findsOneWidget);
  });

  testWidgets('my location without pose shows snackbar', (tester) async {
    final cams = [
      const SpeedcamPoint(id: 'c0', lat: 53.9, lon: 27.5),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
            noLocationMessage: 'No location fix yet',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('speedcam-pack-map-myloc')));
    await tester.pump();
    expect(find.byKey(const ValueKey('speedcam-pack-map-no-location')), findsOneWidget);
    expect(find.text('No location fix yet'), findsOneWidget);
  });

  testWidgets('renders OSM map + caption for cams', (tester) async {
    final cams = [
      for (var i = 0; i < 5; i++)
        SpeedcamPoint(id: 'c$i', lat: 53.9 + i * 0.01, lon: 27.5 + i * 0.01),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
          ),
        ),
      ),
    );
    await tester.pump(); // one frame; do not settle (map timers / fade)
    expect(find.byKey(const ValueKey('speedcam-pack-map-empty')), findsNothing);
    expect(find.byKey(const ValueKey('speedcam-pack-map-caption')), findsOneWidget);
    expect(find.textContaining('5 cameras'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  testWidgets('tap cam marker opens metadata sheet with provenance', (tester) async {
    final cams = [
      const SpeedcamPoint(
        id: 'osm-tap-1',
        lat: 53.9,
        lon: 27.5,
        maxspeed: 70,
        source: 'osm+ynavi',
        lastSeenEpochMs: 123,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('speedcam-cam-tap-osm-tap-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speedcam-cam-tap-osm-tap-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('speedcam-cam-detail')), findsOneWidget);
    expect(find.text('osm-tap-1'), findsOneWidget);
    expect(find.textContaining('osm+ynavi'), findsWidgets);
    expect(speedcamMarkerColor('osm+ynavi'), const Color(0xFFFFB300));
  });

  testWidgets('caption omits showing-cap for packs under kMaxMarkers', (tester) async {
    final cams = [
      for (var i = 0; i < 574; i++)
        SpeedcamPoint(
          id: 'c$i',
          lat: 53.9 + (i % 40) * 0.01,
          lon: 27.5 + (i ~/ 40) * 0.01,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('574 cameras'), findsOneWidget);
    expect(find.textContaining('showing'), findsNothing);
    expect(
      SpeedcamPackMapPreview.kMaxMarkers,
      greaterThanOrEqualTo(2000),
    );
  });

  // 0100 — zoom-aware cam dots / hit targets (larger than pre-0100 constants).
  test('camDotRadius grows with zoom and stays capped for dense packs', () {
    final sparseLo = SpeedcamPackMapPreview.camDotRadius(shownCount: 10, zoom: 11);
    final sparseHi = SpeedcamPackMapPreview.camDotRadius(shownCount: 10, zoom: 15);
    final denseLo = SpeedcamPackMapPreview.camDotRadius(shownCount: 500, zoom: 11);
    final denseHi = SpeedcamPackMapPreview.camDotRadius(shownCount: 500, zoom: 15);

    // Pre-0100 sparse was 3.5 / dense 2.0 — new bases are clearly larger.
    expect(sparseLo, greaterThan(3.5));
    expect(denseLo, greaterThan(2.0));
    expect(sparseHi, greaterThan(sparseLo));
    expect(denseHi, greaterThan(denseLo));
    // Soft caps: readable when zoomed, not a smear.
    expect(denseHi, lessThanOrEqualTo(9.0));
    expect(sparseHi, lessThanOrEqualTo(9.0));
  });

  test('camHitExtent larger than pre-0100 22–28 clamp', () {
    final hitSparse = SpeedcamPackMapPreview.camHitExtent(
      SpeedcamPackMapPreview.camDotRadius(shownCount: 10, zoom: 12),
    );
    final hitDense = SpeedcamPackMapPreview.camHitExtent(
      SpeedcamPackMapPreview.camDotRadius(shownCount: 500, zoom: 12),
    );
    expect(hitSparse, greaterThanOrEqualTo(28.0));
    expect(hitDense, greaterThanOrEqualTo(28.0));
    expect(hitSparse, lessThanOrEqualTo(44.0));
    expect(hitDense, lessThanOrEqualTo(44.0));
    // Old max was 28 — mid/high zoom sparse should clear that.
    final hitZoomed = SpeedcamPackMapPreview.camHitExtent(
      SpeedcamPackMapPreview.camDotRadius(shownCount: 10, zoom: 15),
    );
    expect(hitZoomed, greaterThan(28.0));
  });

  // 0101 — zoom-grid clustering (no flutter_map_marker_cluster dep).
  test('clusterCams merges neighbors at low zoom and splits when zoomed in', () {
    final cams = [
      for (var i = 0; i < 9; i++)
        SpeedcamPoint(
          id: 'n$i',
          lat: 53.90 + (i % 3) * 0.002,
          lon: 27.50 + (i ~/ 3) * 0.002,
        ),
    ];
    final low = SpeedcamPackMapPreview.clusterCams(cams, 9);
    final high = SpeedcamPackMapPreview.clusterCams(cams, 16);
    expect(low.length, lessThan(cams.length));
    expect(low.any((n) => n.isCluster), isTrue);
    expect(high.length, cams.length);
    expect(high.every((n) => !n.isCluster), isTrue);
    expect(low.fold<int>(0, (s, n) => s + n.count), cams.length);
  });

  test('clusterCams keeps full pack count under soft cap for dense 300km-like pack', () {
    // ~3k cams on a ~3°×3° grid — rough full-pack stress without device.
    final cams = [
      for (var i = 0; i < 3000; i++)
        SpeedcamPoint(
          id: 'p$i',
          lat: 52.0 + (i % 60) * 0.05,
          lon: 26.0 + (i ~/ 60) * 0.05,
        ),
    ];
    final sw = Stopwatch()..start();
    final nodesLo = SpeedcamPackMapPreview.clusterCams(cams, 8);
    final nodesMid = SpeedcamPackMapPreview.clusterCams(cams, 11);
    final nodesHi = SpeedcamPackMapPreview.clusterCams(cams, 15);
    sw.stop();
    expect(nodesLo.length, lessThan(SpeedcamPackMapPreview.kMaxMarkers));
    expect(nodesLo.length, lessThan(nodesMid.length));
    expect(nodesMid.fold<int>(0, (s, n) => s + n.count), 3000);
    expect(nodesHi.fold<int>(0, (s, n) => s + n.count), 3000);
    // Pure Dart grid — should be well under a frame on desktop CI.
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('camsInBounds pads and filters', () {
    const cams = [
      SpeedcamPoint(id: 'in', lat: 53.9, lon: 27.5),
      SpeedcamPoint(id: 'out', lat: 55.0, lon: 29.0),
    ];
    final bounds = LatLngBounds(const LatLng(53.85, 27.45), const LatLng(53.95, 27.55));
    final kept = SpeedcamPackMapPreview.camsInBounds(cams, bounds);
    expect(kept.map((c) => c.id), ['in']);
  });

  testWidgets('cluster bubble appears for dense pack at default fit', (tester) async {
    final cams = [
      for (var i = 0; i < 40; i++)
        SpeedcamPoint(
          id: 'd$i',
          lat: 53.9 + (i % 5) * 0.001,
          lon: 27.5 + (i ~/ 5) * 0.001,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(
            cams: cams,
            tileProvider: fakeTiles,
          ),
        ),
      ),
    );
    await tester.pump();
    // At assumed zoom 12 before camera sync, tight 40-cam grid should cluster.
    final clusterTap = find.byWidgetPredicate(
      (w) =>
          w is GestureDetector &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('speedcam-cluster-tap-'),
    );
    expect(clusterTap, findsWidgets);
  });
}

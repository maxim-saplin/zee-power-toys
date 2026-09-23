import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
}

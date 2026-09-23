import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/widgets/speedcam_point_detail_sheet.dart';

void main() {
  test('source labels cover osm / ynavi / merged', () {
    expect(speedcamSourceLabel('overpass'), contains('OSM'));
    expect(speedcamSourceLabel('ynavi'), 'ynavi');
    expect(speedcamSourceLabel('osm+ynavi'), contains('merged'));
    expect(speedcamSourceLabel(null), contains('legacy'));
  });

  test('pickSpeedcamSampleCams prefers merged + osm + ynavi', () {
    final cams = [
      const SpeedcamPoint(id: 'osm-1', lat: 1, lon: 1, source: 'overpass'),
      const SpeedcamPoint(id: 'ynavi:2', lat: 2, lon: 2, source: 'ynavi'),
      const SpeedcamPoint(
        id: 'osm-3',
        lat: 3,
        lon: 3,
        source: 'osm+ynavi',
        lastSeenEpochMs: 42,
      ),
      const SpeedcamPoint(id: 'osm-4', lat: 4, lon: 4, source: 'overpass'),
    ];
    final sample = pickSpeedcamSampleCams(cams);
    expect(sample.map((c) => c.id).toList(), ['osm-3', 'osm-1', 'ynavi:2']);
  });

  test('merged provenance mentions OSM and YNavi field rules', () {
    const cam = SpeedcamPoint(
      id: 'osm-9',
      lat: 53.9,
      lon: 27.5,
      source: 'osm+ynavi',
      maxspeed: 70,
      lastSeenEpochMs: 1000,
    );
    final rows = speedcamFieldProvenance(cam);
    expect(rows.any((e) => e.value.toLowerCase().contains('ynavi')), isTrue);
    expect(rows.any((e) => e.key.contains('direction')), isTrue);
    expect(rows.any((e) => e.value.contains('LANE')), isTrue);
    expect(rows.any((e) => e.value.contains('0092') || e.value.contains('isLaneCam')), isTrue);
  });

  testWidgets('detail sheet shows id source and provenance', (tester) async {
    const cam = SpeedcamPoint(
      id: 'osm-42',
      lat: 53.902,
      lon: 27.561,
      maxspeed: 60,
      direction: '90',
      source: 'osm+ynavi',
      lastSeenEpochMs: 1_700_000_000_000,
      camType: null,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpeedcamPointDetailSheet(cam: cam),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('speedcam-cam-detail')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-cam-detail-id')), findsOneWidget);
    expect(find.text('osm-42'), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-cam-detail-source-badge')), findsOneWidget);
    expect(find.textContaining('osm+ynavi'), findsWidgets);
    expect(
      find.byKey(const ValueKey('speedcam-cam-detail-provenance-title')),
      findsOneWidget,
    );
    expect(find.textContaining('OSM if set, else YNavi'), findsOneWidget);
    expect(find.textContaining('stamped osm+ynavi'), findsOneWidget);
  });

  testWidgets('showSpeedcamPointDetailSheet opens modal', (tester) async {
    const cam = SpeedcamPoint(
      id: 'ynavi:abc',
      lat: 53.9,
      lon: 27.5,
      source: 'ynavi',
      camType: 'LANE_CONTROL',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-detail'),
              onPressed: () => showSpeedcamPointDetailSheet(context, cam),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('speedcam-cam-detail')), findsOneWidget);
    expect(find.text('ynavi:abc'), findsOneWidget);
    expect(find.text('true'), findsWidgets); // isYnaviSourced / isLaneCam
  });
}

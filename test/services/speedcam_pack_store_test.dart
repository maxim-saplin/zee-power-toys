import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/services/speedcam_pack_store.dart';

void main() {
  group('FileSpeedcamPackStore.parseOverpassElements', () {
    test('maps nodes with maxspeed', () {
      final cams = FileSpeedcamPackStore.parseOverpassElements([
        {
          'type': 'node',
          'id': 42,
          'lat': 53.9,
          'lon': 27.5,
          'tags': {'highway': 'speed_camera', 'maxspeed': '60', 'direction': 'N'},
        },
        {'type': 'way', 'id': 1},
      ]);
      expect(cams, hasLength(1));
      expect(cams.first.id, 'osm-42');
      expect(cams.first.maxspeed, 60);
      expect(cams.first.direction, 'N');
    });
  });

  group('FileSpeedcamPackStore', () {
    late Directory root;
    late FileSpeedcamPackStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('speedcam_pack_');
      store = FileSpeedcamPackStore(
        root: root,
        client: MockClient((request) async {
          final fixture = await File(
            'test/fixtures/speedcam_by_overpass_sample.json',
          ).readAsString();
          return http.Response(fixture, 200);
        }),
        clock: () => DateTime.utc(2026, 9, 19, 18),
      );
    });

    tearDown(() async {
      store.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('updatePack downloads, caches, loadCams round-trip', () async {
      expect(await store.current(SpeedcamPackIds.by), isNull);
      final meta = await store.updatePack(SpeedcamPackIds.by);
      expect(meta.camCount, 3);
      expect(meta.id, SpeedcamPackIds.by);
      expect(await store.current(SpeedcamPackIds.by), isNotNull);
      final cams = await store.loadCams(SpeedcamPackIds.by);
      expect(cams, hasLength(3));
      expect(File('${root.path}/by.json').existsSync(), isTrue);
    });

    test('installFixture from Overpass JSON', () async {
      final body = await File(
        'test/fixtures/speedcam_by_overpass_sample.json',
      ).readAsString();
      final meta = await store.installFixture(
        packId: SpeedcamPackIds.by,
        jsonBody: body,
      );
      expect(meta.camCount, 3);
      expect(meta.source, 'fixture');
    });
  });


  group('Overpass headers', () {
    test('POST includes User-Agent and Accept', () async {
      http.BaseRequest? seen;
      final root = await Directory.systemTemp.createTemp('speedcam_ua_');
      final store = FileSpeedcamPackStore(
        root: root,
        client: MockClient((request) async {
          seen = request;
          final fixture = await File(
            'test/fixtures/speedcam_by_overpass_sample.json',
          ).readAsString();
          return http.Response(fixture, 200);
        }),
      );
      await store.updatePack(SpeedcamPackIds.by);
      expect(seen, isNotNull);
      expect(seen!.headers['user-agent'], contains('zee-power-toys'));
      expect(seen!.headers['accept'], 'application/json');
      final body = seen is http.Request ? (seen as http.Request).body : '';
      // Body is form-urlencoded: around: → around%3A
      expect(body, contains('around%3A'));
      expect(body.toLowerCase(), isNot(contains('belarus')));
      store.dispose();
      await root.delete(recursive: true);
    });
  });

  group('FakeSpeedcamPackStore', () {
    test('updatePack then loadCams; offline fails', () async {
      final fake = FakeSpeedcamPackStore();
      expect(await fake.current(SpeedcamPackIds.by), isNull);
      final meta = await fake.updatePack(SpeedcamPackIds.by);
      expect(meta.camCount, greaterThan(0));
      expect(await fake.loadCams(SpeedcamPackIds.by), isNotEmpty);
      fake.offline = true;
      expect(() => fake.updatePack(SpeedcamPackIds.by), throwsStateError);
      fake.dispose();
    });
  });


  group('SpeedcamHarvestArea', () {
    test('overpassQl uses around radius not bbox', () {
      final ql = SpeedcamHarvestArea.overpassQl(
        lat: 53.9,
        lon: 27.5,
        radiusKm: 300,
      );
      expect(ql, contains('around:300000,53.9,27.5'));
      expect(ql, isNot(contains('51.2')));
      expect(ql, isNot(contains('highway"="speed_camera"](51')));
    });

    test('mergeById retains outside-circle cams (no purge)', () {
      const existing = [
        SpeedcamPoint(id: 'osm-old', lat: 52.0, lon: 23.7),
        SpeedcamPoint(id: 'osm-1', lat: 53.9, lon: 27.5),
      ];
      const incoming = [
        SpeedcamPoint(id: 'osm-1', lat: 53.91, lon: 27.56), // upsert
        SpeedcamPoint(id: 'osm-2', lat: 53.92, lon: 27.57),
      ];
      final merged = SpeedcamHarvestArea.mergeById(existing, incoming);
      final ids = merged.map((c) => c.id).toSet();
      expect(ids, containsAll(['osm-old', 'osm-1', 'osm-2']));
      expect(merged.firstWhere((c) => c.id == 'osm-1').lat, 53.91);
      expect(merged, hasLength(3));
    });
  });

  group('FileSpeedcamPackStore.merge harvest', () {
    test('second updatePack keeps cams outside new harvest', () async {
      final root = await Directory.systemTemp.createTemp('speedcam_merge_');
      var call = 0;
      final store = FileSpeedcamPackStore(
        root: root,
        client: MockClient((request) async {
          call++;
          if (call == 1) {
            return http.Response(
              '{"elements":['
              '{"type":"node","id":10,"lat":53.9,"lon":27.5,"tags":{"highway":"speed_camera"}},'
              '{"type":"node","id":11,"lat":52.1,"lon":23.7,"tags":{"highway":"speed_camera"}}'
              ']}',
              200,
            );
          }
          // Second harvest returns only near-center cam (simulates different circle).
          return http.Response(
            '{"elements":['
            '{"type":"node","id":10,"lat":53.905,"lon":27.51,"tags":{"highway":"speed_camera"}},'
            '{"type":"node","id":12,"lat":53.92,"lon":27.55,"tags":{"highway":"speed_camera"}}'
            ']}',
            200,
          );
        }),
        clock: () => DateTime.utc(2026, 9, 20, 12),
      );
      final first = await store.updatePack(
        SpeedcamPackIds.by,
        centerLat: 53.9,
        centerLon: 27.5,
      );
      expect(first.camCount, 2);
      expect(first.coverageLabel, 'within 300 km');
      expect(first.regionLabel.toLowerCase(), isNot(contains('by')));

      final second = await store.updatePack(
        SpeedcamPackIds.by,
        centerLat: 53.9,
        centerLon: 27.5,
      );
      expect(second.lastHarvestCount, 2);
      // osm-11 retained from first harvest even though absent in second response.
      final cams = await store.loadCams(SpeedcamPackIds.by);
      final ids = cams.map((c) => c.id).toSet();
      expect(ids, containsAll(['osm-10', 'osm-11', 'osm-12']));
      expect(second.camCount, 3);

      // Request body used around=
      store.dispose();
      await root.delete(recursive: true);
    });
  });

}

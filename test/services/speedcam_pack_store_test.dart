import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
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
}

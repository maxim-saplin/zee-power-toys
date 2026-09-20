import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam_pack_store.dart';

void main() {
  group('SpeedcamPackMeta.isStale', () {
    test('fresh within window', () {
      final meta = SpeedcamPackMeta(
        id: 'by',
        version: 'v',
        fetchedAt: DateTime.utc(2026, 9, 18),
        camCount: 3,
      );
      expect(
        meta.isStale(afterDays: 7, now: DateTime.utc(2026, 9, 19)),
        isFalse,
      );
    });

    test('stale after N days', () {
      final meta = SpeedcamPackMeta(
        id: 'by',
        version: 'v',
        fetchedAt: DateTime.utc(2026, 9, 1),
        camCount: 3,
      );
      expect(
        meta.isStale(afterDays: 7, now: DateTime.utc(2026, 9, 19)),
        isTrue,
      );
    });
  });

  group('FakeSpeedcamPackStore.refreshIfNeeded', () {
    test('manual policy never auto-updates', () async {
      final store = FakeSpeedcamPackStore();
      expect(
        await store.refreshIfNeeded(
          packId: SpeedcamPackIds.by,
          ifStale: false,
          staleAfterDays: 7,
        ),
        isNull,
      );
      store.dispose();
    });

    test('ifStale fetches when missing', () async {
      final store = FakeSpeedcamPackStore();
      final meta = await store.refreshIfNeeded(
        packId: SpeedcamPackIds.by,
        ifStale: true,
        staleAfterDays: 7,
      );
      expect(meta, isNotNull);
      expect(meta!.camCount, greaterThan(0));
      store.dispose();
    });
  });

  group('FileSpeedcamPackStore.refreshIfNeeded aged', () {
    test('aged pack triggers update', () async {
      final root = await Directory.systemTemp.createTemp('speedcam_stale_');
      final store = FileSpeedcamPackStore(
        root: root,
        client: MockClient((request) async {
          return http.Response(
            await File('test/fixtures/speedcam_by_overpass_sample.json')
                .readAsString(),
            200,
          );
        }),
        clock: () => DateTime.utc(2026, 9, 19, 12),
      );
      // Plant aged pack
      await store.installFixture(
        packId: SpeedcamPackIds.by,
        jsonBody: jsonEncode({
          'meta': {
            'id': 'by',
            'version': 'aged-for-autorfresh',
            'fetchedAt': '2026-08-01T00:00:00.000Z',
            'camCount': 1,
            'source': 'fixture',
            'regionLabel': 'Belarus (BY)',
          },
          'cams': [
            {'id': 'old', 'lat': 53.9, 'lon': 27.5},
          ],
        }),
      );
      final before = await store.current(SpeedcamPackIds.by);
      expect(before!.version, 'aged-for-autorfresh');
      expect(before.isStale(afterDays: 7, now: DateTime.utc(2026, 9, 19)), isTrue);

      final after = await store.refreshIfNeeded(
        packId: SpeedcamPackIds.by,
        ifStale: true,
        staleAfterDays: 7,
        now: DateTime.utc(2026, 9, 19),
      );
      expect(after, isNotNull);
      expect(after!.version, isNot(equals('aged-for-autorfresh')));
      // Merge retains aged 'old' + 3 from Overpass fixture.
      expect(after.camCount, 4);
      expect(after.coverageLabel, contains('300'));
      store.dispose();
      await root.delete(recursive: true);
    });
  });
}

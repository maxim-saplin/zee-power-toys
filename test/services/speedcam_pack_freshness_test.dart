import 'package:flutter_test/flutter_test.dart';
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
}

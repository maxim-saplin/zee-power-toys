import 'dart:async';

import '../speedcam.dart';
import '../speedcam_pack_store.dart';
import 'fake_speedcam_service.dart';

/// Offline Fake — embedded BY sample; updatePack copies sample → "cached".
class FakeSpeedcamPackStore implements SpeedcamPackStore {
  FakeSpeedcamPackStore({List<SpeedcamPoint>? cams})
      : _cams = List<SpeedcamPoint>.unmodifiable(
          cams ?? FakeSpeedcamService.kFakeBySampleCams,
        );

  final List<SpeedcamPoint> _cams;
  SpeedcamPackMeta? _meta;
  final _ctrl = StreamController<SpeedcamPackMeta?>.broadcast();
  bool offline = false;

  @override
  Stream<SpeedcamPackMeta?> watch(String packId) async* {
    yield await current(packId);
    yield* _ctrl.stream.where((m) => m == null || m.id == packId);
  }

  @override
  Future<SpeedcamPackMeta?> current(String packId) async =>
      packId == SpeedcamPackIds.by ? _meta : null;

  @override
  Future<List<SpeedcamPoint>> loadCams(String packId) async {
    if (packId != SpeedcamPackIds.by) return const [];
    return _meta == null ? const [] : _cams;
  }

  @override
  Future<SpeedcamPackMeta?> refreshIfNeeded({
    required String packId,
    required bool ifStale,
    required int staleAfterDays,
    DateTime? now,
  }) async {
    final meta = await current(packId);
    if (!ifStale) return meta;
    if (meta == null || meta.isStale(afterDays: staleAfterDays, now: now)) {
      return updatePack(packId);
    }
    return meta;
  }

  @override
  Future<SpeedcamPackMeta> updatePack(String packId) async {
    if (packId != SpeedcamPackIds.by) {
      throw ArgumentError('unsupported packId=$packId');
    }
    if (offline) {
      throw StateError('offline');
    }
    final now = DateTime.now().toUtc();
    _meta = SpeedcamPackMeta(
      id: packId,
      version: now.toIso8601String(),
      fetchedAt: now,
      camCount: _cams.length,
      source: 'fake',
    );
    _ctrl.add(_meta);
    return _meta!;
  }

  void dispose() => _ctrl.close();
}

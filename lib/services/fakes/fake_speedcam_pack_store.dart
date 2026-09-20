import 'dart:async';

import '../speedcam.dart';
import '../speedcam_pack_store.dart';
import 'fake_speedcam_service.dart';

/// Offline Fake — embedded sample; updatePack merges sample into cache.
class FakeSpeedcamPackStore implements SpeedcamPackStore {
  FakeSpeedcamPackStore({List<SpeedcamPoint>? cams})
      : _seed = List<SpeedcamPoint>.unmodifiable(
          cams ?? FakeSpeedcamService.kFakeBySampleCams,
        );

  final List<SpeedcamPoint> _seed;
  final List<SpeedcamPoint> _cams = [];
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
    return _meta == null ? const [] : List.unmodifiable(_cams);
  }

  @override
  Future<SpeedcamPackMeta?> refreshIfNeeded({
    required String packId,
    required bool ifStale,
    required int staleAfterDays,
    DateTime? now,
    double? centerLat,
    double? centerLon,
  }) async {
    final meta = await current(packId);
    if (!ifStale) return meta;
    if (meta == null || meta.isStale(afterDays: staleAfterDays, now: now)) {
      return updatePack(
        packId,
        centerLat: centerLat,
        centerLon: centerLon,
      );
    }
    return meta;
  }

  @override
  Future<SpeedcamPackMeta> updatePack(
    String packId, {
    double? centerLat,
    double? centerLon,
    double radiusKm = kSpeedcamHarvestRadiusKm,
  }) async {
    if (packId != SpeedcamPackIds.by) {
      throw ArgumentError('unsupported packId=$packId');
    }
    if (offline) {
      throw StateError('offline');
    }
    final lat = centerLat ??
        _meta?.centerLat ??
        kSpeedcamDefaultCenterLat;
    final lon = centerLon ??
        _meta?.centerLon ??
        kSpeedcamDefaultCenterLon;
    final merged = SpeedcamHarvestArea.mergeById(_cams, _seed);
    _cams
      ..clear()
      ..addAll(merged);
    final now = DateTime.now().toUtc();
    _meta = SpeedcamPackMeta(
      id: packId,
      version: now.toIso8601String(),
      fetchedAt: now,
      camCount: _cams.length,
      source: 'fake',
      regionLabel: 'within ${radiusKm.round()} km',
      radiusKm: radiusKm,
      centerLat: lat,
      centerLon: lon,
      lastHarvestCount: _seed.length,
    );
    _ctrl.add(_meta);
    return _meta!;
  }

  void dispose() => _ctrl.close();
}

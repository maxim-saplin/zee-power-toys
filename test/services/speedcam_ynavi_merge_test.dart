import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('mergeOsmWithYnavi dedupes geo-close cams under OSM id', () {
    final osm = [
      const SpeedcamPoint(id: 'osm:1', lat: 53.9, lon: 27.56, maxspeed: 60),
    ];
    final ynavi = [
      const SpeedcamPoint(
        id: 'ynavi:abc',
        lat: 53.90005,
        lon: 27.56005,
        maxspeed: 60,
        source: 'ynavi',
      ),
      const SpeedcamPoint(
        id: 'ynavi:far',
        lat: 54.0,
        lon: 27.7,
        maxspeed: 90,
        source: 'ynavi',
      ),
    ];
    final merged = DefaultSpeedcamService.mergeOsmWithYnavi(osm, ynavi);
    expect(merged.length, 2);
    final near = merged.firstWhere((c) => c.id == 'osm:1');
    expect(near.source, 'osm+ynavi');
    expect(merged.any((c) => c.id == 'ynavi:far'), isTrue);
  });

  test('ingestYnaviEvent dedupes same eventId across ghost+route feeds', () {
    final svc = DefaultSpeedcamService(
      packStore: FakeSpeedcamPackStore(cams: const []),
      fallbackCams: const [],
    );
    Map<Object?, Object?> cam({required String feed}) => {
          'kind': 'cam',
          'lat': 59.840975781,
          'lon': 30.376847172,
          'speedLimit': 60,
          'eventId': 'u211a9f37',
          'source': 'ynavi',
          'feed': feed,
          't_ms': 1,
        };
    svc.setYnaviEnrichEnabled(true); // 0071 gate
    svc.ingestYnaviEvent(cam(feed: 'freeDriveRoute'));
    expect(svc.ynaviSessionEvents, 1);
    svc.ingestYnaviEvent(cam(feed: 'getEvents')); // same eventId — skip
    expect(svc.ynaviSessionEvents, 1);
    final ynaviCams =
        svc.snapshot.cams.where((c) => c.id == 'ynavi:u211a9f37').toList();
    expect(ynaviCams.length, 1);
  });
}

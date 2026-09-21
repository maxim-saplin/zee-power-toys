import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  DefaultSpeedcamService svc() => DefaultSpeedcamService(
        packStore: FakeSpeedcamPackStore(cams: const []),
        fallbackCams: const [
          SpeedcamPoint(id: 'osm:1', lat: 53.9, lon: 27.56, maxspeed: 60, source: 'overpass'),
        ],
      );

  Map<Object?, Object?> cam(String id) => {
        'kind': 'cam',
        'lat': 59.84,
        'lon': 30.37,
        'speedLimit': 60,
        'eventId': id,
        'source': 'ynavi',
        't_ms': DateTime.now().millisecondsSinceEpoch,
      };

  test('0072 counts OSM vs YNavi separately', () {
    final s = svc();
    s.setYnaviEnrichEnabled(true);
    s.ingestYnaviEvent(cam('a'));
    expect(s.osmCamCount, greaterThanOrEqualTo(1));
    expect(s.ynaviCamCount, 1);
  });

  test('0074 collect OFF skips ingest', () {
    final s = svc();
    s.setYnaviEnrichEnabled(true);
    s.setYnaviCollectEnabled(false);
    s.ingestYnaviEvent(cam('b'));
    expect(s.ynaviCamCount, 0);
    expect(s.ynaviSessionEvents, 0);
  });

  test('0074 alert OFF excludes ynavi from camsForAlert', () {
    final s = svc();
    s.setYnaviEnrichEnabled(true);
    s.setYnaviCollectEnabled(true);
    s.ingestYnaviEvent(cam('c'));
    expect(s.ynaviCamCount, 1);
    s.setYnaviAlertEnabled(false);
    expect(s.camsForAlert.any((c) => c.isYnaviSourced), isFalse);
  });

  test('0073 aging drops stale ynavi; renew resets', () async {
    final s = svc();
    s.setYnaviEnrichEnabled(true);
    s.setYnaviPointTtlDays(1);
    final oldMs = DateTime.now()
        .subtract(const Duration(days: 3))
        .millisecondsSinceEpoch;
    s.ingestYnaviEvent({
      'kind': 'cam',
      'lat': 59.84,
      'lon': 30.37,
      'speedLimit': 60,
      'eventId': 'old',
      'source': 'ynavi',
      't_ms': oldMs,
    });
    // Force prune with "now"
    s.setYnaviPointTtlDays(1);
    expect(s.ynaviCamCount, 0);

    s.ingestYnaviEvent(cam('fresh'));
    expect(s.ynaviCamCount, 1);
    // renew same id
    s.ingestYnaviEvent(cam('fresh'));
    expect(s.ynaviCamCount, 1);
  });
}

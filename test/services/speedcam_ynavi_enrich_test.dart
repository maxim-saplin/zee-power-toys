import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('SpeedcamConfig ynaviEnrichEnabled defaults OFF and round-trips', () {
    const c = SpeedcamConfig();
    expect(c.ynaviEnrichEnabled, isFalse);
    final on = c.copyWith(ynaviEnrichEnabled: true);
    expect(on.ynaviEnrichEnabled, isTrue);
    expect(SpeedcamConfig.fromJson(on.toJson()).ynaviEnrichEnabled, isTrue);
    expect(SpeedcamConfig.fromJson(<String, Object?>{}).ynaviEnrichEnabled, isFalse);
  });

  test('DefaultSpeedcamService drops ingest when enrich OFF', () async {
    final svc = DefaultSpeedcamService(
      packStore: FakeSpeedcamPackStore(),
      fallbackCams: const [
        SpeedcamPoint(id: 'osm:1', lat: 59.9, lon: 30.3, maxspeed: 60),
      ],
    );
    expect(svc.ynaviEnrichEnabled, isFalse);
    svc.ingestYnaviEvent({
      'kind': 'cam',
      'lat': 59.79,
      'lon': 30.40,
      'speedLimit': 60,
      'eventId': 'u-test',
      'source': 'ynavi',
    });
    expect(svc.ynaviSessionEvents, 0);
    expect(svc.snapshot.cams.any((c) => c.id.startsWith('ynavi:')), isFalse);

    svc.setYnaviEnrichEnabled(true);
    svc.ingestYnaviEvent({
      'kind': 'cam',
      'lat': 59.79,
      'lon': 30.40,
      'speedLimit': 60,
      'eventId': 'u-test',
      'source': 'ynavi',
    });
    expect(svc.ynaviSessionEvents, 1);
    expect(svc.snapshot.cams.any((c) => c.id == 'ynavi:u-test'), isTrue);

    svc.setYnaviEnrichEnabled(false);
    expect(svc.snapshot.cams.any((c) => c.id.startsWith('ynavi:')), isFalse);
  });
}

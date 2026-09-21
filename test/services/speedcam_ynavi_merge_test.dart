import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
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
}

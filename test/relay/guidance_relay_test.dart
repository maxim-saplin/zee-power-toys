import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/minimap_host.dart';

void main() {
  test('GuidanceEvent JSON round-trips for hub relay', () {
    const e = GuidanceEvent(
      turnIcon: '8',
      distanceM: 250,
      roadName: 'Lenina',
      etaMin: 12,
    );
    final decoded = GuidanceEvent.fromJson(
      Map<String, Object?>.from(jsonDecode(jsonEncode(e.toJson())) as Map),
    );
    expect(decoded, equals(e));
  });

  test('empty GuidanceEvent serializes to empty map', () {
    const e = GuidanceEvent();
    expect(e.toJson(), isEmpty);
    expect(GuidanceEvent.fromJson(<String, Object?>{}), equals(e));
  });
}

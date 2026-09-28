import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/media_now_playing.dart';

void main() {
  test('media relay payload round-trips via fromJson', () {
    const np = MediaNowPlaying(
      artist: 'Zeekr',
      title: 'Cruise',
      progress: 0.33,
      isPlaying: true,
    );
    final encoded = jsonEncode(np.toJson());
    final decoded = MediaNowPlaying.fromJson(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );
    expect(decoded, equals(np));
  });

  test('clear payload decodes to null', () {
    final encoded = jsonEncode(<String, Object?>{'clear': true});
    final decoded = MediaNowPlaying.fromJson(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );
    expect(decoded, isNull);
  });
}

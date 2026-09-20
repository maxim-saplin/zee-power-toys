import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/providers/guidance.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/minimap_host.dart';

void main() {
  // 0055 redirect: Flutter MinimapGuidanceOverlay deleted — street/ETA come
  // from YNavi native map-pixel chrome. Keep relay/provider smoke for FL.
  test('FakeMinimapHost guidance stream feeds latestGuidanceProvider', () async {
    final host = FakeMinimapHost();
    final container = ProviderContainer(
      overrides: [minimapHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(guidanceEventsProvider, (_, __) {});
    addTearDown(sub.close);

    expect(container.read(latestGuidanceProvider), isNull);
    host.emitGuidance(const GuidanceEvent(roadName: 'Lenina', etaMin: 5));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(latestGuidanceProvider)?.roadName, 'Lenina');
    expect(container.read(latestGuidanceProvider)?.etaMin, 5);
  });
}

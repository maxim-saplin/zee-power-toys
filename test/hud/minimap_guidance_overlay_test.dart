import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/minimap_guidance_overlay.dart';
import 'package:zee_power_toys/providers/guidance.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/minimap_host.dart';

void main() {
  testWidgets('paints street + ETA from GuidanceEvent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinimapGuidanceOverlay(
            event: GuidanceEvent(
              roadName: 'Independence Ave',
              distanceM: 350,
              etaMin: 12,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Independence Ave'), findsOneWidget);
    expect(find.textContaining('ETA'), findsOneWidget);
    expect(find.textContaining('350 m'), findsOneWidget);
  });

  testWidgets('empty event paints nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinimapGuidanceOverlay(event: GuidanceEvent()),
        ),
      ),
    );
    expect(find.byType(MinimapGuidanceOverlay), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  test('FakeMinimapHost guidance stream feeds latestGuidanceProvider', () async {
    final host = FakeMinimapHost();
    final container = ProviderContainer(
      overrides: [minimapHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    // Listen before emit so broadcast stream delivers.
    final sub = container.listen(guidanceEventsProvider, (_, __) {});
    addTearDown(sub.close);

    expect(container.read(latestGuidanceProvider), isNull);
    host.emitGuidance(const GuidanceEvent(roadName: 'Lenina', etaMin: 5));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(latestGuidanceProvider)?.roadName, 'Lenina');
    expect(container.read(latestGuidanceProvider)?.etaMin, 5);
  });
}

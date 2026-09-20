import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/widgets/speedcam_pack_map_preview.dart';

void main() {
  testWidgets('empty state is honest', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(cams: []),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('speedcam-pack-map-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('speedcam-pack-map-caption')), findsNothing);
  });

  testWidgets('renders markers caption for cams', (tester) async {
    final cams = [
      for (var i = 0; i < 5; i++)
        SpeedcamPoint(id: 'c$i', lat: 53.9 + i * 0.01, lon: 27.5 + i * 0.01),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedcamPackMapPreview(cams: cams),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('speedcam-pack-map-empty')), findsNothing);
    expect(find.byKey(const ValueKey('speedcam-pack-map-caption')), findsOneWidget);
    expect(find.textContaining('5 cameras'), findsOneWidget);
  });
}

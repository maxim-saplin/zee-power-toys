import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/screens/about_screen.dart';

void main() {
  testWidgets('About shows Speedcam OSM credit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('about-speedcam-credit')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);
    expect(find.textContaining('ODbL'), findsOneWidget);
  });
}

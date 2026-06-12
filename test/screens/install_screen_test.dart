import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/l10n/app_localizations.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/screens/install_screen.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/installer.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, ConfigStore store, FakeInstaller installer) =>
    ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(installer),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

Future<(SharedPrefsConfigStore, FakeInstaller)> _makeFixture() async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  final installer = FakeInstaller();
  return (store, installer);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InstallScreen', () {
    testWidgets('renders two install cards', (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      expect(find.text('Modded Launcher'), findsOneWidget);
      expect(find.text('YNavi mod (HUD)'), findsOneWidget);
    });

    testWidgets('both Install/Update buttons present', (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      expect(find.byKey(const ValueKey('install-launcher')), findsOneWidget);
      expect(find.byKey(const ValueKey('install-ynavi')), findsOneWidget);
    });

    testWidgets(
        'tapping install-launcher shows downloading phase via FakeInstaller',
        (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      // Tap the launcher Install button.
      await tester.tap(find.byKey(const ValueKey('install-launcher')));

      // Drain the full FakeInstaller sequence (3 × 50ms delays) so no pending
      // timers remain when the test ends.  Check each phase along the way.
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Downloading…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
    });

    testWidgets(
        'install-launcher progresses through all phases to done via FakeInstaller',
        (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('install-launcher')));

      // Pump through the FakeInstaller delays (3 × 50 ms + settle).
      await tester.pump(const Duration(milliseconds: 10));  // downloading 0.0 emitted
      expect(find.text('Downloading…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));  // downloading 0.5
      expect(find.text('Downloading…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));  // installing 0.8
      expect(find.text('Installing…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));  // done 1.0
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('GithubAsset model fields are accessible', (tester) async {
      // Model test — verifies GithubAsset holds repo/branch/path and exposes
      // the resolved LFS download URL.
      const asset = GithubAsset(
        repo: 'owner/repo',
        branch: 'main',
        path: 'apps/app.apk',
      );
      expect(asset.repo, equals('owner/repo'));
      expect(asset.branch, equals('main'));
      expect(asset.path, equals('apps/app.apk'));
      expect(
        asset.downloadUrl,
        equals('https://media.githubusercontent.com/media/owner/repo/main/apps/app.apk'),
      );
    });

    testWidgets('InstallProgress model phase + fraction', (tester) async {
      // Model test — verifies InstallProgress carries phase and fraction.
      const p = InstallProgress(
        phase: InstallPhase.downloading,
        fraction: 0.5,
        message: null,
      );
      expect(p.phase, equals(InstallPhase.downloading));
      expect(p.fraction, equals(0.5));
      expect(p.message, isNull);
    });

    testWidgets('FakeInstaller emits downloading → installing → done stream',
        (tester) async {
      // Mount a minimal widget so the test binding's fake clock is active.
      await tester.pumpWidget(const SizedBox());

      final installer = FakeInstaller();
      const asset = GithubAsset(repo: 'r', branch: 'b', path: 'a.apk');

      final phases = <InstallPhase>[];
      installer.install(asset).listen((p) => phases.add(p.phase));

      // FakeInstaller yields: downloading@0ms, downloading@50ms, installing@100ms, done@150ms.
      await tester.pump(const Duration(milliseconds: 10));   // downloading 0.0
      await tester.pump(const Duration(milliseconds: 60));   // downloading 0.5
      await tester.pump(const Duration(milliseconds: 60));   // installing 0.8
      await tester.pump(const Duration(milliseconds: 60));   // done 1.0

      expect(phases, contains(InstallPhase.downloading));
      expect(phases, contains(InstallPhase.installing));
      expect(phases.last, equals(InstallPhase.done));
    });
  });
}

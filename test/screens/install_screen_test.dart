import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/install_screen.dart';
import 'package:zee_power_toys/services/app_self_update.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/installer.dart';
import 'package:zee_power_toys/services/install_targets.dart';
import 'package:zee_power_toys/services/package_status.dart';
import 'package:zee_power_toys/services/fakes/fake_package_status.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, ConfigStore store, Installer installer) =>
    wrapWithProviders(child, store: store, installer: installer);

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


/// Emits [events] with a short delay between each (after the first).
class _ScriptedInstaller implements Installer {
  _ScriptedInstaller(this.events);

  final List<InstallProgress> events;

  @override
  Stream<InstallProgress> install(GithubAsset asset) async* {
    for (var i = 0; i < events.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      yield events[i];
    }
  }
}

void main() {
  group('InstallScreen', () {
    testWidgets('renders self-update + three companion cards', (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      expect(find.byKey(const ValueKey('card-self-update')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-launcher')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-ynavi')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-ynavi-os7')), findsOneWidget);
    });

    testWidgets('Install buttons for launcher + both YNavi variants', (tester) async {
      final (store, installer) = await _makeFixture();

      await tester.pumpWidget(_wrap(const InstallScreen(), store, installer));
      await tester.pump();

      expect(find.byKey(const ValueKey('install-launcher')), findsOneWidget);
      expect(find.byKey(const ValueKey('install-ynavi')), findsOneWidget);
      expect(find.byKey(const ValueKey('install-ynavi-os7')), findsOneWidget);
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

      await tester.pump(const Duration(milliseconds: 60));  // installing 1.0
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
      await tester.pump(const Duration(milliseconds: 60));   // installing 1.0
      await tester.pump(const Duration(milliseconds: 60));   // done 1.0

      expect(phases, contains(InstallPhase.downloading));
      expect(phases, contains(InstallPhase.installing));
      expect(phases.last, equals(InstallPhase.done));
    });

    testWidgets('installProgressBarValue: download determinate, install spinner',
        (tester) async {
      // 0086: native historically emitted installing@0.8 after download@~1.0.
      expect(
        installProgressBarValue(const InstallProgress(
          phase: InstallPhase.downloading,
          fraction: 1.0,
        )),
        equals(1.0),
      );
      expect(
        installProgressBarValue(const InstallProgress(
          phase: InstallPhase.installing,
          fraction: 0.8,
        )),
        isNull,
      );
      expect(
        installProgressBarValue(const InstallProgress(
          phase: InstallPhase.installing,
          fraction: 1.0,
        )),
        isNull,
      );
      expect(
        installProgressBarValue(const InstallProgress(
          phase: InstallPhase.done,
          fraction: 1.0,
        )),
        equals(1.0),
      );
      expect(
        installProgressBarValue(const InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0.0,
        )),
        isNull,
      );
    });

    testWidgets(
        '0086: launcher bar does not reverse when installing fraction < download',
        (tester) async {
      final (store, _) = await _makeFixture();
      final scripted = _ScriptedInstaller([
        const InstallProgress(phase: InstallPhase.downloading, fraction: 0.5),
        const InstallProgress(phase: InstallPhase.downloading, fraction: 1.0),
        // Legacy backstep fraction — bar must go indeterminate, not 0.8.
        const InstallProgress(phase: InstallPhase.installing, fraction: 0.8),
        const InstallProgress(phase: InstallPhase.done, fraction: 1.0),
      ]);

      await tester.pumpWidget(_wrap(const InstallScreen(), store, scripted));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('install-launcher')));
      await tester.pump(); // first event: downloading 0.5
      expect(find.text('Downloading…'), findsOneWidget);
      var bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('card-launcher')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, equals(0.5));

      await tester.pump(const Duration(milliseconds: 60)); // downloading 1.0
      bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('card-launcher')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, equals(1.0));

      await tester.pump(const Duration(milliseconds: 60)); // installing 0.8
      expect(find.text('Installing…'), findsOneWidget);
      bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('card-launcher')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, isNull); // indeterminate — no visual backstep

      await tester.pump(const Duration(milliseconds: 60)); // done
      expect(find.text('Done'), findsOneWidget);
      bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('card-launcher')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, equals(1.0));
    });

    testWidgets('0103: companion Update when installed < Release pin', (tester) async {
      final (store, installer) = await _makeFixture();
      final packages = FakePackageStatus(probes: {
        CompanionPackages.launcher: const PackageProbe(
          state: PackageInstallState.installed,
          versionCode: 1,
        ),
        CompanionPackages.ynavi: const PackageProbe(
          state: PackageInstallState.installed,
          versionCode: kYnaviReleaseVersionCode,
        ),
      });
      await tester.pumpWidget(
        wrapWithProviders(
          const InstallScreen(),
          store: store,
          installer: installer,
          packageStatus: packages,
        ),
      );
      await tester.pumpAndSettle();
      // Launcher button should say Update
      final launcherBtn = find.descendant(
        of: find.byKey(const ValueKey('card-launcher')),
        matching: find.byKey(const ValueKey('install-launcher')),
      );
      expect(launcherBtn, findsOneWidget);
      expect(
        find.descendant(of: launcherBtn, matching: find.text('Update')),
        findsOneWidget,
      );
      expect(find.textContaining('Update available:'), findsWidgets);
      // YNavi same pin → Reinstall
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-ynavi')),
          matching: find.text('Reinstall'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('0115: Toys version check starts on open without tap', (tester) async {
      final (store, installer) = await _makeFixture();
      var checks = 0;
      final gate = Completer<AppUpdateCheck>();
      Future<AppUpdateCheck> checker() {
        checks++;
        return gate.future;
      }

      await tester.pumpWidget(
        wrapWithProviders(
          const InstallScreen(),
          store: store,
          installer: installer,
          appUpdateChecker: checker,
        ),
      );
      await tester.pump(); // initState kicked _runCheck — still in flight
      expect(checks, 1);
      expect(find.text('Checking…'), findsOneWidget);
      // No tap required — auto path only
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);

      gate.complete(const AppUpdateNonePublished());
      await tester.pumpAndSettle();
      expect(find.text('Checking…'), findsNothing);
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
    });

    testWidgets('0115: soft fail keeps last known + shows error', (tester) async {
      final (store, installer) = await _makeFixture();
      var n = 0;
      Future<AppUpdateCheck> checker() async {
        n++;
        if (n == 1) return const AppUpdateNonePublished();
        return const AppUpdateCheckFailed('GitHub HTTP 403');
      }

      await tester.pumpWidget(
        wrapWithProviders(
          const InstallScreen(),
          store: store,
          installer: installer,
          appUpdateChecker: checker,
        ),
      );
      await tester.pumpAndSettle();
      expect(n, 1);
      // Manual refresh still available
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pumpAndSettle();
      expect(n, 2);
      // Last known (none published) retained + error surfaced
      expect(find.textContaining('403'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
    });

    testWidgets('0115: offline soft fail shows error without hang', (tester) async {
      final (store, installer) = await _makeFixture();
      await tester.pumpWidget(
        wrapWithProviders(
          const InstallScreen(),
          store: store,
          installer: installer,
          appUpdateChecker: () async =>
              const AppUpdateCheckFailed('GitHub HTTP 403'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('403'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
    });

    testWidgets('0103: companion Install when missing', (tester) async {
      final (store, installer) = await _makeFixture();
      final packages = FakePackageStatus(probes: {
        CompanionPackages.launcher: const PackageProbe(
          state: PackageInstallState.missing,
        ),
      });
      await tester.pumpWidget(
        wrapWithProviders(
          const InstallScreen(),
          store: store,
          installer: installer,
          packageStatus: packages,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-launcher')),
          matching: find.text('Install'),
        ),
        findsOneWidget,
      );
    });
  });
}

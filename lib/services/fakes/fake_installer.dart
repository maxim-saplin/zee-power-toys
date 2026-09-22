import 'dart:async';

import '../installer.dart';

/// T1 fake for [Installer].
/// Emits a short downloading → installing → done progress sequence.
class FakeInstaller implements Installer {
  @override
  Stream<InstallProgress> install(GithubAsset asset) async* {
    yield const InstallProgress(phase: InstallPhase.downloading, fraction: 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield const InstallProgress(phase: InstallPhase.downloading, fraction: 0.5);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield const InstallProgress(phase: InstallPhase.installing, fraction: 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield const InstallProgress(phase: InstallPhase.done, fraction: 1.0);
  }
}

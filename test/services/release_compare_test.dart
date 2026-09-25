import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/package_status.dart';
import 'package:zee_power_toys/services/release_compare.dart';

void main() {
  group('compareVersionCodes', () {
    test('older / same / newer', () {
      expect(compareVersionCodes(10, 20), VersionRelation.older);
      expect(compareVersionCodes(20, 20), VersionRelation.same);
      expect(compareVersionCodes(30, 20), VersionRelation.newer);
    });
  });

  group('releaseActionFor', () {
    test('missing → install', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.missing,
          installedCode: null,
          releaseCode: 100,
        ),
        ReleaseActionKind.install,
      );
    });

    test('unknown → installOrUpdate', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.unknown,
          installedCode: null,
          releaseCode: 100,
        ),
        ReleaseActionKind.installOrUpdate,
      );
    });

    test('installed without code → installOrUpdate', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.installed,
          installedCode: null,
          releaseCode: 100,
        ),
        ReleaseActionKind.installOrUpdate,
      );
    });

    test('installed < release → update', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.installed,
          installedCode: 50,
          releaseCode: 100,
        ),
        ReleaseActionKind.update,
      );
    });

    test('installed == release → reinstall', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.installed,
          installedCode: 100,
          releaseCode: 100,
        ),
        ReleaseActionKind.reinstall,
      );
    });

    test('installed > release → tipAhead', () {
      expect(
        releaseActionFor(
          state: PackageInstallState.installed,
          installedCode: 200,
          releaseCode: 100,
        ),
        ReleaseActionKind.tipAhead,
      );
    });
  });

  group('selfUpdateActionFor', () {
    test('maps relations', () {
      expect(selfUpdateActionFor(installedCode: 1, remoteCode: 2), ReleaseActionKind.update);
      expect(selfUpdateActionFor(installedCode: 2, remoteCode: 2), ReleaseActionKind.reinstall);
      expect(selfUpdateActionFor(installedCode: 3, remoteCode: 2), ReleaseActionKind.tipAhead);
    });
  });
}

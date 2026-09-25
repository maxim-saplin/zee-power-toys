import 'package_status.dart';

/// How installed versionCode relates to a Release pin / remote code.
enum VersionRelation {
  /// installed < release → offer Update
  older,

  /// installed == release → offer Reinstall
  same,

  /// installed > release → lab tip ahead of published Release
  newer,
}

/// Pure numeric compare (0103).
VersionRelation compareVersionCodes(int installedCode, int releaseCode) {
  if (installedCode < releaseCode) return VersionRelation.older;
  if (installedCode > releaseCode) return VersionRelation.newer;
  return VersionRelation.same;
}

/// Button / status action for Install self-update + companion cards (0103).
enum ReleaseActionKind {
  /// Package missing → Install
  install,

  /// Probe unknown → keep honest Install / Update
  installOrUpdate,

  /// installed < Release → Update
  update,

  /// installed == Release → Reinstall (same asset)
  reinstall,

  /// installed > Release (lab tip) → soft Reinstall Release
  tipAhead,
}

/// Map package probe + Release pin → action kind.
ReleaseActionKind releaseActionFor({
  required PackageInstallState state,
  int? installedCode,
  required int releaseCode,
}) {
  switch (state) {
    case PackageInstallState.missing:
      return ReleaseActionKind.install;
    case PackageInstallState.unknown:
      return ReleaseActionKind.installOrUpdate;
    case PackageInstallState.installed:
      if (installedCode == null) {
        // Installed but no versionCode (old channel / failure) — honest blur.
        return ReleaseActionKind.installOrUpdate;
      }
      switch (compareVersionCodes(installedCode, releaseCode)) {
        case VersionRelation.older:
          return ReleaseActionKind.update;
        case VersionRelation.same:
          return ReleaseActionKind.reinstall;
        case VersionRelation.newer:
          return ReleaseActionKind.tipAhead;
      }
  }
}

/// Self-update result → action (after a successful check with a remote code).
ReleaseActionKind selfUpdateActionFor({
  required int installedCode,
  required int remoteCode,
}) {
  switch (compareVersionCodes(installedCode, remoteCode)) {
    case VersionRelation.older:
      return ReleaseActionKind.update;
    case VersionRelation.same:
      return ReleaseActionKind.reinstall;
    case VersionRelation.newer:
      return ReleaseActionKind.tipAhead;
  }
}

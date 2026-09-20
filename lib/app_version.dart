/// Compile-time app identity — keep in sync with `pubspec.yaml` `version:`.
///
/// GitHub self-update (0069) compares [appVersionCode] to the latest public
/// Release tag `1.0.0+N` (or `v1.0.0+N`) for maxim-saplin/zee-power-toys.
library;

/// Semver name (MAJOR.MINOR.PATCH) without build.
const String appVersionName = '1.0.0';

/// Android-style versionCode — the `+BUILD` integer from pubspec.
const int appVersionCode = 4;

/// Full pubspec-style version string.
const String appVersionFull = '1.0.0+4';

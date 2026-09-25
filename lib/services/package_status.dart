/// Package install-status probe (Launcher / YNavi companions).
enum PackageInstallState { installed, missing, unknown }

/// Result of probing a companion package (0103: includes versionCode when known).
class PackageProbe {
  const PackageProbe({
    required this.state,
    this.versionCode,
    this.versionName,
  });

  final PackageInstallState state;
  final int? versionCode;
  final String? versionName;

  bool get isInstalled => state == PackageInstallState.installed;
}

abstract class PackageStatus {
  /// Honest status for [packageName]. Desktop/T1 → [PackageInstallState.unknown]
  /// unless a fake overrides it. Android uses PackageManager.
  Future<PackageInstallState> statusFor(String packageName);

  /// 0103: status + versionCode/versionName when the platform can supply them.
  /// Default maps [statusFor] only (no version).
  Future<PackageProbe> probe(String packageName) async {
    return PackageProbe(state: await statusFor(packageName));
  }
}

/// Canonical companion package ids for home-status cards.
abstract final class CompanionPackages {
  static const launcher = 'ecarx.launcher3';
  static const ynavi = 'ru.yandex.yandexnavi';
}

/// Package install-status probe (Launcher / YNavi companions).
enum PackageInstallState { installed, missing, unknown }

abstract class PackageStatus {
  /// Honest status for [packageName]. Desktop/T1 → [PackageInstallState.unknown]
  /// unless a fake overrides it. Android uses PackageManager.
  Future<PackageInstallState> statusFor(String packageName);
}

/// Canonical companion package ids for home-status cards.
abstract final class CompanionPackages {
  static const launcher = 'ecarx.launcher3';
  static const ynavi = 'ru.yandex.yandexnavi';
}

/// Mirrors Kotlin `InstallerController.isSelfUpdateUrl` (0084).
///
/// Self-update PackageInstaller commits kill this process, so native defers
/// them until companion installs finish.  Keep this predicate in sync with
/// `InstallerController.kt`.
bool isSelfUpdateUrl(String url) {
  final name = url.split('?').first.split('/').last;
  if (name == 'zee-power-toys.apk' || name == 'app-release.apk') {
    return true;
  }
  return url.contains('/maxim-saplin/zee-power-toys/') &&
      name.toLowerCase().endsWith('.apk');
}

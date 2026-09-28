import '../package_status.dart';

/// T1 fake — defaults to [PackageInstallState.unknown] (honest on desktop).
class FakePackageStatus implements PackageStatus {
  FakePackageStatus({
    Map<String, PackageInstallState>? seed,
    Map<String, PackageProbe>? probes,
    this.uninstallResult = UninstallLaunchResult.launched,
    this.autoMarkMissingOnUninstall = true,
    this.uninstallError,
  })  : _seed = Map<String, PackageInstallState>.from(seed ?? const {}),
        _probes = Map<String, PackageProbe>.from(probes ?? const {});

  final Map<String, PackageInstallState> _seed;
  final Map<String, PackageProbe> _probes;

  /// What [requestUninstall] returns (0121 tests).
  UninstallLaunchResult uninstallResult;

  /// When true and result is [launched], probe flips to missing (simulates user OK).
  bool autoMarkMissingOnUninstall;

  /// Surfaced via [lastUninstallError] when result is failed.
  String? uninstallError;

  /// Packages that received [requestUninstall] (order preserved).
  final List<String> uninstallRequests = <String>[];

  void setStatus(String packageName, PackageInstallState state) {
    _seed[packageName] = state;
    _probes.remove(packageName);
  }

  void setProbe(String packageName, PackageProbe probe) {
    _probes[packageName] = probe;
    _seed[packageName] = probe.state;
  }

  @override
  String? get lastUninstallError => uninstallError;

  @override
  Future<PackageInstallState> statusFor(String packageName) async =>
      _probes[packageName]?.state ??
      _seed[packageName] ??
      PackageInstallState.unknown;

  @override
  Future<PackageProbe> probe(String packageName) async {
    final p = _probes[packageName];
    if (p != null) return p;
    return PackageProbe(
      state: _seed[packageName] ?? PackageInstallState.unknown,
    );
  }

  @override
  Future<UninstallLaunchResult> requestUninstall(String packageName) async {
    uninstallRequests.add(packageName);
    if (uninstallResult == UninstallLaunchResult.launched &&
        autoMarkMissingOnUninstall) {
      setProbe(
        packageName,
        const PackageProbe(state: PackageInstallState.missing),
      );
    }
    return uninstallResult;
  }
}

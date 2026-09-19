import '../package_status.dart';

/// T1 fake — defaults to [PackageInstallState.unknown] (honest on desktop).
class FakePackageStatus implements PackageStatus {
  FakePackageStatus({Map<String, PackageInstallState>? seed})
      : _seed = Map<String, PackageInstallState>.from(seed ?? const {});

  final Map<String, PackageInstallState> _seed;

  void setStatus(String packageName, PackageInstallState state) {
    _seed[packageName] = state;
  }

  @override
  Future<PackageInstallState> statusFor(String packageName) async =>
      _seed[packageName] ?? PackageInstallState.unknown;
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../package_status.dart';

/// Android [PackageStatus] via MethodChannel `zee/packages`.
class NativePackageStatus implements PackageStatus {
  NativePackageStatus({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('zee/packages');

  final MethodChannel _channel;

  @override
  Future<PackageInstallState> statusFor(String packageName) async {
    if (kIsWeb) return PackageInstallState.unknown;
    try {
      final raw = await _channel.invokeMethod<String>('isInstalled', {
        'packageName': packageName,
      });
      switch (raw) {
        case 'installed':
          return PackageInstallState.installed;
        case 'missing':
          return PackageInstallState.missing;
        default:
          return PackageInstallState.unknown;
      }
    } catch (_) {
      return PackageInstallState.unknown;
    }
  }
}

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
    final p = await probe(packageName);
    return p.state;
  }

  @override
  Future<PackageProbe> probe(String packageName) async {
    if (kIsWeb) {
      return const PackageProbe(state: PackageInstallState.unknown);
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>('probe', {
        'packageName': packageName,
      });
      if (raw is Map) {
        return _fromMap(Map<Object?, Object?>.from(raw));
      }
      // Legacy string reply from older natives / isInstalled fallback.
      if (raw is String) {
        return PackageProbe(state: _stateFromRaw(raw));
      }
      // Fall back to isInstalled for older APKs without probe.
      final legacy = await _channel.invokeMethod<String>('isInstalled', {
        'packageName': packageName,
      });
      return PackageProbe(state: _stateFromRaw(legacy));
    } catch (_) {
      return const PackageProbe(state: PackageInstallState.unknown);
    }
  }

  static PackageProbe _fromMap(Map<Object?, Object?> map) {
    final state = _stateFromRaw(map['state'] as String?);
    final codeRaw = map['versionCode'];
    int? code;
    if (codeRaw is int) {
      code = codeRaw;
    } else if (codeRaw is num) {
      code = codeRaw.toInt();
    } else if (codeRaw is String) {
      code = int.tryParse(codeRaw);
    }
    final name = map['versionName'] as String?;
    return PackageProbe(
      state: state,
      versionCode: state == PackageInstallState.installed ? code : null,
      versionName: state == PackageInstallState.installed ? name : null,
    );
  }

  static PackageInstallState _stateFromRaw(String? raw) {
    switch (raw) {
      case 'installed':
        return PackageInstallState.installed;
      case 'missing':
        return PackageInstallState.missing;
      default:
        return PackageInstallState.unknown;
    }
  }
}

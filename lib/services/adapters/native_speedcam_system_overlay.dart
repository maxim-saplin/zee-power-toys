import 'package:flutter/services.dart';

import '../speedcam_system_overlay.dart';

/// Android MethodChannel bridge for [SpeedcamSystemOverlayController] (0070 Flutter surface).
class NativeSpeedcamSystemOverlay implements SpeedcamSystemOverlay {
  static const _ch = MethodChannel('zee/speedcam/system_overlay');

  @override
  Future<bool> canDrawOverlays() async {
    final v = await _ch.invokeMethod<bool>('canDrawOverlays');
    return v ?? false;
  }

  @override
  Future<void> openPermissionSettings() =>
      _ch.invokeMethod<void>('openPermissionSettings');

  @override
  Future<void> setEnabled(bool enabled) =>
      _ch.invokeMethod<void>('setEnabled', <String, Object?>{'enabled': enabled});

  @override
  Future<void> update({
    required bool visible,
    String title = '',
    String subtitle = '',
    double? distanceM,
    bool dangerous = false,
  }) =>
      _ch.invokeMethod<void>('update', <String, Object?>{
        'visible': visible,
        'title': title,
        'subtitle': subtitle,
        'distanceM': distanceM,
        'dangerous': dangerous,
      });

  @override
  Future<void> hide() => _ch.invokeMethod<void>('hide');
}

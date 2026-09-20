import '../speedcam_system_overlay.dart';

/// T1 / desktop no-op overlay.
class FakeSpeedcamSystemOverlay implements SpeedcamSystemOverlay {
  bool enabled = false;
  bool permissionGranted = true;
  int updateCount = 0;
  bool lastVisible = false;

  @override
  Future<bool> canDrawOverlays() async => permissionGranted;

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
    if (!enabled) lastVisible = false;
  }

  @override
  Future<void> update({
    required bool visible,
    String title = '',
    String subtitle = '',
    double? distanceM,
    bool dangerous = false,
  }) async {
    updateCount++;
    lastVisible = enabled && permissionGranted && visible;
  }

  @override
  Future<void> hide() async {
    lastVisible = false;
  }
}

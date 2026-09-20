/// 0065 — DHU Speedcam system overlay (draw-over-apps).
abstract class SpeedcamSystemOverlay {
  Future<bool> canDrawOverlays();
  Future<void> openPermissionSettings();
  Future<void> setEnabled(bool enabled);
  Future<void> update({
    required bool visible,
    String title = '',
    String subtitle = '',
    double? distanceM,
    bool dangerous = false,
  });
  Future<void> hide();
}

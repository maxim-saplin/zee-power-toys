import 'dart:ui' show Rect;

/// HUD surface lifecycle port.
/// On T1 the DesktopHudHost wraps the desktop_multi_window second window;
/// on Android the native HudHost wraps a Presentation.
abstract class HudHost {
  Future<void> show();
  Future<void> hide();
  Future<void> applySafeArea(Rect safeArea);
}

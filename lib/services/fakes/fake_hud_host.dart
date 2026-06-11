import 'dart:ui' show Rect;

import '../hud_host.dart';

/// T1 fake for [HudHost].
/// show/hide/applySafeArea are no-ops on the desktop tier — the HUD window is
/// already managed by desktop_multi_window in main.dart.
class FakeHudHost implements HudHost {
  Rect? lastSafeArea;
  bool visible = false;

  @override
  Future<void> show() async => visible = true;

  @override
  Future<void> hide() async => visible = false;

  @override
  Future<void> applySafeArea(Rect safeArea) async => lastSafeArea = safeArea;
}

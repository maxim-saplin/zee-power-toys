import 'package:flutter/services.dart';

import '../hud_host.dart';

/// Android adapter for [HudHost] over the native `zee/hud_lifecycle` MethodChannel.
///
/// show() → native setupHud() (idempotent: NOOP if engine already running).
/// hide() → native tearDownHud(): dismisses Presentation + destroys HUD FlutterEngine
///          + stops MinimapView render thread (ADR 0001, Principle 2, QA4-1).
///
/// Toggling hudEnabled true→false→true is clean and idempotent.
/// After re-enable the native side fires hudReady on zee/minimap, which triggers
/// NativeMinimapHost.onHudReady → re-application of the minimap config.
class NativeHudHost implements HudHost {
  static const MethodChannel _ch = MethodChannel('zee/hud_lifecycle');

  @override
  Future<void> show() async {
    await _ch.invokeMethod<void>('show');
  }

  @override
  Future<void> hide() async {
    await _ch.invokeMethod<void>('hide');
  }

  @override
  // Safe Area is handled by the HUD Flutter isolate directly via the relay;
  // no native action is required here.
  Future<void> applySafeArea(Rect safeArea) async {}
}

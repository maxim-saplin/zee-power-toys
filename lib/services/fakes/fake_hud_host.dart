import '../hud_host.dart';

/// Off-car fake for [HudHost].
///
/// [show]/[hide] only record intent: on the desktop tier the second window is
/// created directly in `main.dart`, so there is no surface for this fake to own.
/// That is a known fidelity gap — the "HUD engine runs only while the HUD is
/// active" guarantee (ADR 0001) is real on Android, where `tearDownHud()`
/// destroys the engine, but not here.
class FakeHudHost implements HudHost {
  bool visible = false;

  @override
  Future<void> show() async => visible = true;

  @override
  Future<void> hide() async => visible = false;
}

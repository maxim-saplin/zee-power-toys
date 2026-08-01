/// HUD surface lifecycle port.
///
/// On Android the native implementation wraps a `Presentation` on the HUD's
/// secondary display; off-car a Dart fake stands in.
///
/// The Safe Area is deliberately **not** part of this port. It is derived from
/// the real display metrics reported by the native `onHudReady` callback and
/// turned into fractions by `computeHudSafeAreaFracs()`
/// (`lib/services/minimap_viewport.dart`), then persisted in `AppConfig` and
/// read by `HudRoot` — see `lib/main.dart`. An earlier `applySafeArea(Rect)`
/// method existed here with an empty native body and no callers anywhere; it
/// was removed rather than wired, because the `onHudReady` path already owns
/// this and a second route would be two sources of truth.
abstract class HudHost {
  Future<void> show();
  Future<void> hide();
}

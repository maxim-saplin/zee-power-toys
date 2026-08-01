// StateProvider is a "legacy" (pre-codegen) Riverpod 3.x API — still fully
// supported, just not re-exported from the main library barrel anymore.
import 'package:hooks_riverpod/legacy.dart';

/// The real HUD backing-display geometry, as reported by native's
/// `onHudReady` (Block 0027) — the same data already surfaced to the
/// Feedback Loop via `ext.zee.readViewModel`'s `hud` field
/// (`lib/debug/agent_extensions.dart`'s `getHudGeometry` callback), now also
/// reachable from ordinary app UI (not just the debug bridge) so a screen can
/// honestly answer "what display am I actually driving — the emulator's
/// 1024×576 overlay, or the car's?".
///
/// Null until the first `onHudReady` fires (T2/T3 only — T1 desktop never
/// reports one; there is no native Presentation there).
class HudGeometryInfo {
  const HudGeometryInfo({
    required this.displayId,
    required this.w,
    required this.h,
    required this.dpi,
  });

  /// Logical Android display id the HUD Presentation lives on. Null if the
  /// native callback did not report one (older/mocked paths).
  final int? displayId;

  /// Backing-display width in physical pixels.
  final int w;

  /// Backing-display height in physical pixels.
  final int h;

  /// Backing-display density in dpi.
  final int dpi;
}

/// Live HUD geometry — set by `dhuMain` (`lib/main.dart`) as soon as native's
/// `onHudReady` fires. Null on T1 desktop (no native Presentation) and on the
/// HUD isolate itself (only the DHU surface owns the NativeMinimapHost that
/// receives the callback). This is a plain [StateProvider] (not derived from
/// a stream) because `NativeMinimapHost.onHudReady` is a single-subscription
/// stream already consumed once by `dhuMain`'s own Safe-Area-recompute
/// listener — re-listening here would throw "Stream has already been
/// listened to". `dhuMain` instead writes through this provider's notifier
/// from that one listener.
final hudGeometryProvider = StateProvider<HudGeometryInfo?>((ref) => null);

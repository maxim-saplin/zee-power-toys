---
status: done
labels: [hud, minimap, android, two-engine]
created: 2026-06-11
satisfies: Foundation Minimap under-layer (ADR 0001/0005) + HUD · Minimap (host)
blocked-by: [0004, 0005]
modules: [MinimapHost, HudHost]
tier: T2
---

# 0009 — Minimap under-layer (native transparent-overlay compositing)

## Block scope
Composite the HUD as a **transparent Flutter overlay over a native `TextureView` Minimap** with the green-yellow HUD-readability **`ColorMatrix` filter**, controlled by a lean **idempotent `setMinimap`** command (ADR 0001 exception, ADR 0005). On the emulator there is no real YNavi, so the under-layer shows an animated **placeholder** TextureView; the real YNavi bind is T3. This delivers the Foundation "Minimap under-layer" item and de-risks the on-car compositing claim.

## Touches
- **Satisfies:** Foundation — ADR 0001 (Minimap exception: native map under transparent Flutter), ADR 0005 (own the host); HUD · Minimap (host half).
- **Modules:** MinimapHost (NativeMinimapHost), HudHost (transparent HUD surface on Android).
- **ADRs:** 0001, 0005, 0003.

## Grounding — port from the PoC
- multidisplay_poc EXP3 (native `TextureView` under a transparent `FlutterTextureView`): `_poc/multidisplay_poc/.../MainActivity.kt` (`setupExp3Transparent`, `MinimapView`, `zee/minimap` idempotent `setMinimap`/`setMinimapBounds`/`setMinimapParam`). Distilled: [`docs/knowledge/pocs-twoengine-relay-and-overlay.md`](../knowledge/pocs-twoengine-relay-and-overlay.md), [`docs/knowledge/hud-presentation-host.md`](../knowledge/hud-presentation-host.md) (the green-yellow `ColorMatrix` values).
- Current host: `android/.../MainActivity.kt` (today the HUD uses an OPAQUE `FlutterSurfaceView` attached to the HUD engine on the Presentation) — switch the HUD presentation to a `FrameLayout` with a native `MinimapView` (TextureView, ColorMatrix filter) UNDER a transparent `FlutterTextureView(isOpaque=false)`.

## What to build
- **Native:** in `MainActivity.setupHud`, replace the bare `FlutterView(FlutterSurfaceView)` with EXP3's layered `FrameLayout`: native `MinimapView` (animated placeholder + `ColorMatrixColorFilter` green-yellow) at the bottom, transparent `FlutterTextureView`-backed `FlutterView` on top, attached to the HUD engine. Register the `zee/minimap` MethodChannel on the **DHU** engine (the DHU app drives it) → idempotent `setMinimap(enabled)`, `setMinimapBounds(x,y,w,h)`, `setMinimapParam(key,value)` (port verbatim from the PoC; log NOOP when already in the requested state).
- **Dart:** `lib/services/adapters/native_minimap_host.dart` — `NativeMinimapHost implements MinimapHost` over `zee/minimap`; inject on Android (T1 keeps `FakeMinimapHost`). Wire a DHU control (and an `ext.zee.*` path) so the loop can drive `enable`/`bounds`.
- Keep the proven two-engine rendering working: blinker/battery overlay must still render, now transparent over the Minimap.

## Definition of Done (runtime-confirmed on T2)
Inherits [PRINCIPLES.md](../PRINCIPLES.md). On `emulator-5554` (overlay display set):
- [x] HUD renders the **transparent Flutter overlay** (blinker/battery) OVER the native Minimap placeholder with the green-yellow filter. — artifact: device composite [`shots/t2-minimap-device.png`](../../shots/t2-minimap-device.png) (overlay display shows green-yellow tinted native Minimap + Flutter marks).
- [x] `setMinimap(false)` hides the native Minimap; `setMinimap(true)` shows it; a repeat logs `NOOP (already shown)` (idempotent). — artifact: logcat `setMinimap(...) APPLIED` / `NOOP`.
- [x] Two engines + relay + signal inject still work (no regression). — artifact: whoami-all dhu+hud; tap + inject reflected on hud.
- [x] analyze clean; 77 tests green; one APK (linux + apk build). Principles: idempotent commands; HUD/Minimap only while HUD active.

## Reconciliation
Built by Sonnet, integrated + corrected + verified by the orchestrator (Opus) on T2 (composite) and T1 (no-regression), 2026-06-11.
1. **Transparent composite works on the emulator GPU** — the device screencap shows the native green-yellow `MinimapView` on the Overlay display with the transparent `FlutterTextureView(isOpaque=false)` HUD overlay on top. The `ext.zee.shot` RepaintBoundary captures only the Flutter layer (by design); the device composite is the proof. (ADR 0001 said "confirm on-car" — now also confirmed on T2 with a placeholder; YNavi bind remains T3.)
2. **HUD backdrop is platform-conditional (orchestrator fix).** The build set the HUD `Scaffold` to `Colors.transparent` (needed on Android), which regressed the **T1** HUD to a white backdrop. Fixed: `Colors.transparent` on Android (composite over native), `Colors.black` on desktop (emissive, no under-layer). Re-verified T1 HUD is black ([`shots/t1-hud-black-fixed.png`](../../shots/t1-hud-black-fixed.png)).
3. **ColorMatrix** applied via `setLayerType(LAYER_TYPE_HARDWARE, paint)` on our own `lockCanvas` MinimapView (correct for our draw loop; the knowledge-doc caveat about TextureView+external SurfaceTexture applies to the real YNavi surface — a T3 item, using the full hue-passthrough matrix from phase0 `createHudFilterPaint`).
4. **`NativeMinimapHost`** injected on Android; `FakeMinimapHost` on T1. `ext.zee.minimap` (DHU only) drives `enable/bounds/params`.

## Notes
YNavi *bind* (real map + trip data) is T3 — this Block proves the compositing + control API with a placeholder. The Minimap config UI (enable/disable, presets, dark/light auto) is the next Block (0010).

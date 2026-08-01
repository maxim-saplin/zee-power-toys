---
status: done
labels: [hud, minimap, foundation]
created: 2025-06-12
satisfies: foundation
blocked-by: []
modules: [MinimapHost, ConfigStore, HudHost]
tier: T2
---

# 0025 — Minimap Safe-Area confinement — phase0 square viewport geometry + empirical Safe Area (T2)

## Block scope
Fix the minimap rendering to a properly-confined square inside the HUD Safe Area, matching the geometry model from `phase0/IAppHostStub.computeViewportRect()`.

Root cause (found during 0022 QA): `setMinimapBounds` was sizing the `MinimapView` (TextureView child) but NOT its parent `filterWrapper` (the `FrameLayout` carrying `LAYER_TYPE_HARDWARE`). The hardware-layer FrameLayout remained `MATCH_PARENT` (1280×720 — the T2 emulator overlay in use at the time; historical, since corrected to 1024×576/213 to match the real HUD), so its `ColorMatrix` layer covered the full display regardless of the TextureView's own size. Battery widget overlapped.

Two additional structural fixes:
1. **Phase0 viewport math** — replace hand-calibrated fraction-based bounds with the canonical dp-constant model from phase0 (`hudSafeAreaWidthDp=616, hudSafeAreaHeightDp=175, hudSafeAreaOffsetXDp=+5, hudSafeAreaOffsetYDp=+6`; `squareSizeFraction=0.9, squarePaddingDp=31`). Gives display-density-independent geometry.
2. **Ordering** — `setBounds` must be called **before** `enable` so `filterWrapper` is sized before `parkForYNavi` triggers `onSurfaceTextureAvailable` (which reads viewport dimensions to size the SurfaceTexture buffer).

## Touches
- **Satisfies:** Foundation — layout-confinement follow-up deferred from 0022
- **Modules:** `MinimapHost`, `NativeMinimapHost`, `ConfigStore` (HudSafeArea), `main.dart` wiring
- **ADRs:** ADR 0001 (HUD surface model), ADR 0005 (native Android integration)

## Definition of Done
- [x] Runtime-confirmed on **Tier T2** — artifact: `shots/redo/t2-hud-minimap-confined.png` — 210×210px square at (278,263) left side, green YNavi roads, battery widget at right (~960,275), no overlap
- [x] `flutter analyze` clean (0 issues)
- [x] `flutter test` 228/228 pass (new `test/minimap_viewport_test.dart` — 19 geometry tests)
- [x] `filterWrapper` sized to viewport rect (not `MATCH_PARENT`) — native fix in `MainActivity.kt`
- [x] `setBounds` called before `enable` — ordering fix in `_applyMinimapConfig`
- [x] Phase0 Safe Area dp-constants encoded and applied at `onHudReady` time

## Reconciliation

### Root cause divergence from 0022
Block 0022 thought the `setMinimapBounds` call was the complete fix (sizing `MinimapView`). In fact the `filterWrapper` parent FrameLayout was never sized, so the hardware layer remained full-display. The fix required sizing `filterWrapper` via `LayoutParams(w, h)` with `leftMargin/topMargin` + `Gravity.TOP|START`.

### Phase0 geometry model
The dp-constant model from `IAppHostStub.kt` L208-211 and `HudSettings.kt`:
- **Safe Area**: `hudSafeAreaWidthDp=616, hudSafeAreaHeightDp=175, hudSafeAreaOffsetXDp=+5, hudSafeAreaOffsetYDp=+6`
- **Minimap**: `squareSizeFraction=0.9` (default `balanced`), `squarePaddingDp=31`, `minimapScale=0.5`
- **Placement**: `SQUARE_LEFT` — left-align within Safe Area with padding

**T2 computed viewport** (1280×720 @ 213dpi, `balanced`, `SQUARE_LEFT` — **historical**: the
emulator overlay in use at the time this Block ran; the real HUD geometry, emulator and car
alike, is 1024×576 @ 213dpi, yielding `Rect.fromLTWH(150, 191, 210, 210)` instead — see
`CONTEXT.md`'s Minimap entry and `test/minimap_viewport_test.dart`'s T3-nominal group):
- density = 213/160 = 1.33125
- safeW ≈ 820px, safeH ≈ 233px; safeLeft ≈ 237, safeRight ≈ 1057; safeTop ≈ 252, safeBottom ≈ 485
- side = 233 × 0.9 ≈ **210px**; paddingPx ≈ 41
- **Viewport: Rect(278, 263, 488, 473)** — 210×210px square at SQUARE_LEFT

### New files / changes
- `lib/services/minimap_viewport.dart` — NEW: `computeMinimapViewport()` + `computeHudSafeAreaFracs()` with phase0 dp-constants; preset map (`compact`→0.75, `balanced`→0.90, `large`→1.0)
- `lib/main.dart` — added `_hudDpi`, updated `onHudReady` listener (now 3-tuple), replaced `_applyMinimapConfig` (dp-model + setBounds-before-enable)
- `lib/services/adapters/native_minimap_host.dart` — `onHudReady` stream: `(double, double)` → `(double, double, double)` (adds dpi)
- `android/.../MainActivity.kt` — `setMinimapBounds` handler: sizes `filterWrapper`, not `MinimapView`; added `import android.view.Gravity`
- `test/minimap_viewport_test.dart` — NEW: 19 unit tests covering square output, side≈210px, inside Safe Area, no battery collision, preset ordering, clamping, `computeHudSafeAreaFracs`
- `lib/services/config_store.dart` — comment update only (HudSafeArea doc)

### BACKLOG updated
- Deferred "Minimap surface confinement" → resolved as Block 0025

## Notes
- `zoom-out factor` (minimap scale 0.5 = 2× oversample) is handled by YNavi natively; `computeMinimapViewport` returns the *viewport rect* only, not the buffer size.
- The `hudReady` native call now passes `dpi` as a third argument; the Android side already emits `w`, `h`, and `dpi` keys in the `hudReady` MethodChannel arguments (confirmed in `IAppHostStub` approach).
- Storage issue: T2 emulator /data was at 90% capacity; required `flutter build apk --debug --split-per-abi` (x86_64 variant ≈67MB) + uninstalling `com.zeekr.phase0` first.

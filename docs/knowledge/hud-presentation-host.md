# Knowledge: hud-presentation-host

# HUD Presentation Host — Phase 0 Deep Dive

## Overview

Path C ("Unified HUD Presentation") is the primary production path. All HUD content is composited inside a single `android.app.Presentation` subclass (`HudPresentation`, inner class of `CarAppHostService`) running on the secondary display. The `Presentation` is owned by `CarAppHostService`, a foreground `Service` (`startForeground`), and is created only when at least one feature (minimap or blinker) is active, and dismissed when all features deactivate.

---

## 1. Display-2 Selection

**File:** `CarAppHostService.kt:994-999`

```kotlin
private fun selectHudDisplay(): Display? {
    val displayManager = getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager ?: return null
    val displays = displayManager.displays
    return displays.firstOrNull { it.displayId == HUD_DISPLAY_ID }         // (1) exact displayId=2
        ?: displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull()  // (2) PRESENTATION category
        ?: displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }  // (3) any non-default
}
```

`HUD_DISPLAY_ID = 2` is the hard-coded constant (`CarAppHostService.kt:1972`). On the Zeekr S2 car the HUD is always `displayId=2` at 1024×576, 213 dpi.

**Fallback — virtual display (emulator):** If no physical display-2 exists and `SYSTEM_ALERT_WINDOW` is granted, `ensureHudPresentation()` (`CarAppHostService.kt:860-880`) calls `HudVirtualDisplay.ensureDisplay()`. `HudVirtualDisplay` (`HudVirtualDisplay.kt`) creates a floating `TYPE_APPLICATION_OVERLAY` window containing a `TextureView`, then calls `DisplayManager.createVirtualDisplay("HUD_Preview", w, h, densityDpi, Surface(st), VIRTUAL_DISPLAY_FLAG_PRESENTATION)` to get a `VirtualDisplay` whose `display` object is passed to `showPresentationOnDisplay()`. Virtual display default size: 460×260 dp (`HudVirtualDisplay.kt:127-128`).

Same three-step fallback logic exists in `DirectHudPresentationManager.findHudDisplay()` (`DirectHudPresentationManager.kt:66-78`).

---

## 2. Presentation Creation and Window Setup

**File:** `CarAppHostService.kt:884-915` (`showPresentationOnDisplay`) and `HudPresentation.onCreate` at line 1436.

Constructor:
```kotlin
val hudPresentation = HudPresentation(this, display, surfaceEventsCallback, hudSettings)
hudPresentation.show()
```

`HudPresentation` extends `android.app.Presentation(context, display)`. `Presentation`'s constructor creates a display-specific `Context` with the target display's `DisplayMetrics`, so all dp→px conversions use the HUD display's density (213 dpi on Zeekr).

`HudPresentation.onCreate` window setup (`CarAppHostService.kt:1439-1441`):
```kotlin
window?.let { w ->
    w.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
    w.setFormat(PixelFormat.TRANSLUCENT)
}
```
The window is fully transparent so only the composited layer stack shows on the HUD projector.

After `show()`, the initial viewport is computed and applied immediately (`CarAppHostService.kt:906-915`):
```kotlin
val metrics = DisplayMetrics().also { display.getMetrics(it) }
val viewport = IAppHostStub.computeViewportRect(
    metrics.widthPixels, metrics.heightPixels, metrics.densityDpi, minimapViewportMode,
    hudSettings.squareSizeFraction, hudSettings.squarePaddingDp
)
hudPresentation.updateSurfaceLayout(viewport)
```

---

## 3. View Layer Stack (Z-order, bottom to top)

**File:** `CarAppHostService.kt:1443-1572` (`HudPresentation.onCreate`)

```
FrameLayout container (TRANSPARENT background, MATCH_PARENT x MATCH_PARENT)
 ├── [0] FrameLayout filterWrapper  — hardware-layer ColorMatrix host; sized to viewport rect
 │     └── TextureView textureView — YNavi map surface; isOpaque=false; MATCH_PARENT inside wrapper
 ├── [1] View mapBlocker            — Color.BLACK, MATCH_PARENT; VISIBLE only in guidance-only mode without active navigation
 ├── [2] GuidanceOverlayView guidanceOverlay — TBT arrows/distances/ETA; MATCH_PARENT
 ├── [3] SpeedCamOverlayView speedcamOverlay — speed camera alerts; MATCH_PARENT
 ├── [4] BlinkerOverlayView blinkerOverlay   — two amber dots; initial visibility=GONE
 └── [5] View rightEdgeMask         — Color.BLACK strip at right edge of viewport; hides YNavi distance bar
```

All children are added with `MATCH_PARENT × MATCH_PARENT` `LayoutParams` except `rightEdgeMask` which starts at `0×0` and is resized in `updateSurfaceLayout`.

**Why TextureView needs a filterWrapper parent** (`CarAppHostService.kt:1501-1504`):
> "Applying `setLayerType` directly on a TextureView does NOT filter SurfaceTexture content; the parent ViewGroup's layer captures the composited pixels."

---

## 4. Safe Area Rectangle — Exact Values

**Source of truth:** `IAppHostStub.kt:208-211` (constants) and `dimens.xml:47-49` (layout XML use).

| Constant | Value | Meaning |
|---|---|---|
| `SAFE_AREA_WIDTH_DP` | 616 dp | HUD optical visible width |
| `SAFE_AREA_HEIGHT_DP` | 175 dp | HUD optical visible height |
| `SAFE_AREA_OFFSET_X_DP` | +5 dp | Safe area center offset right from display center |
| `SAFE_AREA_OFFSET_Y_DP` | +6 dp | Safe area center offset down from display center |

At 1024×576 display, 213 dpi (density = 213/160 = 1.33125):
- `safeW ≈ 820 px`, `safeH ≈ 233 px`
- `safeCenterX ≈ 519 px`, `safeCenterY ≈ 296 px`
- Safe rect: left≈109, right≈929, top≈180, bottom≈413

From `dimens.xml`:
- `hud_bounds_width`: 616dp
- `hud_bounds_height`: 175dp
- `hud_bounds_offset_y`: -8dp (note: slight discrepancy to the +6 center offset; bounds diagnostic uses a fixed negative Y offset)

**Edge values documented in HUD.md:**
- Left edge: -303 dp from display center
- Right edge: +313 dp from display center
- Top edge: -81.5 dp from display center
- Bottom edge: +93.5 dp from display center

**How safe area is applied** — `IAppHostStub.computeViewportRect()` (`IAppHostStub.kt:220-253`):
```kotlin
val safeCenterX = displayWidth / 2 + (SAFE_AREA_OFFSET_X_DP * density).roundToInt()
val safeCenterY = displayHeight / 2 + (SAFE_AREA_OFFSET_Y_DP * density).roundToInt()
val safeW = (SAFE_AREA_WIDTH_DP * density).roundToInt().coerceAtMost(displayWidth)
val safeH = (SAFE_AREA_HEIGHT_DP * density).roundToInt().coerceAtMost(displayHeight)
val safeLeft = (safeCenterX - safeW / 2).coerceAtLeast(0)
val safeRight = (safeLeft + safeW).coerceAtMost(displayWidth)

val side = (safeH * sizeFraction).roundToInt()     // square side = safeH × squareSizeFraction
val top = safeCenterY - side / 2                   // vertically centered on safe area

val left = when (mode) {
    SQUARE_LEFT  -> safeLeft + paddingPx           // left edge + 31dp padding
    SQUARE_RIGHT -> safeRight - side - paddingPx   // right edge - side - 31dp padding
    else -> 0
}
```

For `FULL_SCREEN` mode the viewport is the entire display (`Rect(0,0,displayWidth,displayHeight)`).

**User-adjustable offset** (`CarAppHostService.kt:1024-1036`):
```kotlin
val dx = (hudSettings.offsetXDp * density).toInt()
val dy = (hudSettings.offsetYDp * density).toInt()
viewport.offset(dx, dy)
// Clamped to display bounds on all 4 sides
```

---

## 5. Viewport Applied to filterWrapper

**File:** `CarAppHostService.kt:1575-1649` (`HudPresentation.updateSurfaceLayout`)

```kotlin
val wrapperParams = filterWrapper.layoutParams as FrameLayout.LayoutParams
wrapperParams.width = viewport.width()
wrapperParams.height = viewport.height()
wrapperParams.leftMargin = viewport.left
wrapperParams.topMargin = viewport.top
wrapperParams.gravity = Gravity.TOP or Gravity.START
filterWrapper.layoutParams = wrapperParams
```

The `filterWrapper` (and thus the `TextureView` inside it) is placed at the exact pixel coordinates of the computed viewport rect. Overlay layers (`mapBlocker`, `guidanceOverlay`) are aligned to the same rect. `rightEdgeMask` is positioned at `viewport.right - maskWidthPx`.

---

## 6. Buffer Oversampling (minimapScale)

**File:** `CarAppHostService.kt:1585-1606`

```kotlin
val scale = settings.minimapScale.coerceIn(0.25f, 1.0f)   // default 0.5
val bufW = (viewport.width() / scale).toInt()              // at scale=0.5: 2× view width
val bufH = (viewport.height() / scale).toInt()
textureView.surfaceTexture?.setDefaultBufferSize(bufW, bufH)
```

`SurfaceTexture.setDefaultBufferSize(bufW, bufH)` tells YNavi to render into a larger buffer. Android's compositor scales it down to the `TextureView`'s view dimensions, effectively "zooming out" the map. At `minimapScale=0.5`, YNavi renders 2× the viewport in each dimension.

The buffer size is stored as `pendingBufW/pendingBufH` so it is re-applied in `onSurfaceTextureAvailable` if the surface is not yet ready at layout time.

---

## 7. ColorMatrix HUD Filter — Complete Values

**File:** `CarAppHostService.kt:1695-1784` (`applyHudFilter` + `createHudFilterPaint`)

The filter is applied as a `Paint.colorFilter = ColorMatrixColorFilter(cm)` on the `filterWrapper` via `filterWrapper.setLayerType(LAYER_TYPE_HARDWARE, filterPaint)`.

When filter is disabled: `filterWrapper.setLayerType(LAYER_TYPE_NONE, null)`.

**Color presets** (`createHudFilterPaint`, line 1719-1725):
```
preset=0: (tR=0.7, tG=1.0, tB=0.1)  green-yellow (default)
preset=1: (tR=0.1, tG=0.9, tB=1.0)  cyan
preset=2: (tR=1.0, tG=1.0, tB=1.0)  white
preset=3: (tR=1.0, tG=0.75, tB=0.0) amber
preset=4: (tR=1.0, tG=0.15, tB=0.0) red
```

**Default `HudSettings` filter values** (`HudSettings.kt:43-56`):
```
filterContrast  = 3.0f
filterThreshold = 150
filterPreset    = 2  (white)
filterSaturation = 0f (fully monochrome-tinted)
filterBrightness = -20
filterInvert    = false
filterHuePass   = 1.0f
filterHueAngle  = 290
colorPreset     = 0 (White)
multicolor      = true
```

**Defined COLOR_PRESETS** (`HudSettings.kt:132-138`):
```
preset 0 "White":       filterPreset=2, c=3.0, t=150, b=-20, s=0.0, huePass=1.0, hueAngle=290
preset 1 "Green-yellow": filterPreset=0, c=3.0, t=150, b=-20, s=0.0, huePass=1.0, hueAngle=120
preset 2 "Cyan":        filterPreset=1, c=3.0, t=150, b=-20, s=0.0, huePass=1.0, hueAngle=180
preset 3 "Amber":       filterPreset=3, c=3.0, t=150, b=-20, s=0.0, huePass=1.0, hueAngle=60
preset 4 "Red":         filterPreset=4, c=3.0, t=150, b=-20, s=0.0, huePass=1.0, hueAngle=0
```

**Matrix construction** (`CarAppHostService.kt:1743-1768`):
```kotlin
// Luminance weights: lr=0.3, lg=0.6, lb=0.1
// ms = 1-saturation (monochrome weight)
// Base matrix row for red channel:
//   rR = ms*lr*c*tR + s*c
//   rG = ms*lg*c*tR
//   rB = ms*lb*c*tR
//   offset_R = ms*t*tR + s*t + b   where t = -threshold

val cm = ColorMatrix(floatArrayOf(
    rR*(1-hpR)+c*hpR,  rG*(1-hpR),        rB*(1-hpR),        0f, rOff*(1-hpR)+(t+b)*hpR,
    gR*(1-hpG),        gG*(1-hpG)+c*hpG,  gB*(1-hpG),        0f, gOff*(1-hpG)+(t+b)*hpG,
    bR*(1-hpB),        bG*(1-hpB),        bB*(1-hpB)+c*hpB,  0f, bOff*(1-hpB)+(t+b)*hpB,
    0f,                0f,                0f,                1f, 0f
))
```

Hue passthrough (`hpR`, `hpG`, `hpB`) lerps each row between the tinted-contrast matrix and the identity-contrast row based on proximity to the target hue angle. At `huePass=1.0, hueAngle=290` (near magenta/white), pixels near that hue retain their original color, all others become contrast-boosted monochrome-tinted.

**Invert pre-concat** (`CarAppHostService.kt:1773-1782`):
```kotlin
val inv = ColorMatrix(floatArrayOf(
    -1f,0f,0f,0f,255f, 0f,-1f,0f,0f,255f, 0f,0f,-1f,0f,255f, 0f,0f,0f,1f,0f
))
cm.preConcat(inv)  // apply invert before tint
```

**TextureView invalidation workaround** (`CarAppHostService.kt:1492-1498`):
When `filterWrapper.layerType == LAYER_TYPE_HARDWARE`, the hardware layer caches its output. Since `TextureView` updates bypass the `View` invalidation system, `onSurfaceTextureUpdated` explicitly calls `filterWrapper.invalidate()` to force a hardware-layer repaint.

---

## 8. Blinker Dot Placement

**File:** `dimens.xml:19-21`, `BlinkerOverlayView.kt:50-71`

```xml
<dimen name="beautiful_indicator_dot">12dp</dimen>
<dimen name="beautiful_dot_offset_x_left">-282dp</dimen>
<dimen name="beautiful_dot_offset_x_right">292dp</dimen>
<dimen name="beautiful_dot_offset_y">-60.5dp</dimen>
```

Dots are centered in the `BlinkerOverlayView` (which spans the full display) then offset via `View.translationX/Y`. This places them 15 dp inside the safe area top-left and top-right corners (safe area extends ±303/313 dp from center; dots at ±282/292 dp).

Blink interval: 450 ms. BCM signal polling: 50 ms when API available, 1000 ms backoff when not. BCM function IDs: `BCM_LEFT=0x21051100`, `BCM_RIGHT=0x21051200` (via `com.ecarx.xui.adaptapi.car.Car` reflection).

---

## 9. Presentation Lifecycle (create only while active)

**CarAppHostService.kt — key lifecycle points:**

- **`onCreate`** (`line 258`): Calls `ensureHudPresentation()` immediately.
- **`ensureHudPresentation()`** (`line 860`): `if (presentation != null) return@post` — creates at most once.
- **`ACTION_START`** (`line 355`): Sets `minimapActive=true`, calls `ensureHudPresentation()`, then `presentation?.showMap()`.
- **`ACTION_STOP`** (`line 373`): Sets `minimapActive=false`, calls `stopHosting(keepPresentation = blinkerActive)`. Presentation is kept alive if blinker is still on; otherwise dismissed and `stopSelf()`.
- **`ACTION_SHOW_BLINKER`** (`line 439`): Sets `blinkerActive=true`, `ensureHudPresentation()`, `presentation?.showBlinker()`.
- **`ACTION_HIDE_BLINKER`** (`line 448`): Sets `blinkerActive=false`. If `!minimapActive`, presentation is dismissed and `stopSelf()`.
- **`stopHosting(keepPresentation=false)`** (`line 926`): Calls `onAppPause→onAppStop→unbindService` on worker thread, then on main thread: `presentation?.dismiss(); presentation = null; stopSelf()`.

The Presentation is destroyed only when both `minimapActive=false` AND `blinkerActive=false`.

**On service destroy** (`line 525-548`): `stopHosting(keepPresentation=false)`, `hudVirtualDisplay.release()`, cleanup of GPS/SpeedCam receivers.

---

## 10. Surface Contract with YNavi (CarApp)

The service binds to YNavi's `NavigationCarAppService` via `CarAppService.SERVICE_INTERFACE` intent. `IAppHostStub` implements `IAppHost.Stub`. When YNavi calls `setSurfaceCallback(ISurfaceCallback)`, the stub stores it. When the `TextureView` surface becomes available, `surfaceEvents.onSurfaceReady` is called, which calls `IAppHostStub.onSurfaceReady(SurfaceContainer)`. This fires `ISurfaceCallback.onSurfaceAvailable` and `onVisibleAreaChanged` to YNavi.

`onVisibleAreaChanged` / `onStableAreaChanged` always report `Rect(0, 0, container.width, container.height)` — i.e., the full buffer — because the `TextureView` is already physically sized to the viewport rect; YNavi fills the entire surface (`IAppHostStub.kt:162-169`).

---

## 11. Right-Edge Mask Geometry

**File:** `CarAppHostService.kt:1609-1618`

```kotlin
val maskWidthPx = (dp(context, RIGHT_EDGE_MASK_WIDTH_DP) * scale).toInt()  // 40dp × minimapScale
// positioned at: left = viewport.right - maskWidthPx, top = viewport.top
// size: maskWidthPx × viewport.height
```

`RIGHT_EDGE_MASK_WIDTH_DP = 40` (`CarAppHostService.kt:1981`). Width is scaled by `minimapScale` so that as the buffer is oversampled, the mask proportionally covers the YNavi distance bar.

---

## 12. GuidanceOverlay Independent Scale

**File:** `CarAppHostService.kt:1633-1649`

```kotlin
val oScale = settings.overlayScale.coerceIn(0.25f, 1.0f)  // default 0.5
if (oScale < 1.0f) {
    overlayParams.width = (viewport.width() / oScale).toInt()   // layout size inflated
    overlayParams.height = (viewport.height() / oScale).toInt()
}
overlayParams.leftMargin = viewport.left
guidanceOverlay.scaleX = oScale   // View.scaleX/Y compress back to viewport size
guidanceOverlay.scaleY = oScale
guidanceOverlay.pivotX = 0f; guidanceOverlay.pivotY = 0f  // scale from top-left
```

Layout inflated by `1/overlayScale`, then `scaleX/Y=overlayScale` applied to visually shrink it back to viewport bounds, keeping Gravity.TOP and BOTTOM anchors at the visual edges.

---

## 13. ADB Broadcast Interface

Broadcast action: `com.zeekr.phase0.CARAPP_HOST` → received by `CarAppHostReceiver`. Key `--es action` values:
- `start` / `stop` — minimap on/off; optionally `--es viewport full_screen|square_left|square_right`
- `blinker_on` / `blinker_off`
- `configure` — sets any `HudSettings` field live; full key list in `CarAppHostReceiver.kt:117-127`
- `screenshot` — `PixelCopy` or canvas fallback → PNG at specified path

Service actions (direct `startForegroundService`): `ACTION_START`, `ACTION_STOP`, `ACTION_SHOW_BLINKER`, `ACTION_HIDE_BLINKER`, `ACTION_APPLY_SETTINGS`, `ACTION_SET_MINIMAP_VIEWPORT`, `ACTION_SCREENSHOT`, `ACTION_BOOT_AUTOSTART`.

---

## 14. Virtual Display (Emulator Path)

**File:** `HudVirtualDisplay.kt`

When no `displayId=2` exists and `SYSTEM_ALERT_WINDOW` is granted:
1. Creates a `FrameLayout` with dark background.
2. Adds a `TextureView` inside it.
3. Adds the root as `TYPE_APPLICATION_OVERLAY` at bottom-right corner, 90% alpha.
4. In `onSurfaceTextureAvailable`: calls `DisplayManager.createVirtualDisplay("HUD_Preview", w, h, densityDpi, Surface(st), VIRTUAL_DISPLAY_FLAG_PRESENTATION)`.
5. Returns the `VirtualDisplay.display` object, which is passed to `showPresentationOnDisplay()`.
6. The `HudPresentation` renders into this virtual display, which is composited into the overlay window visible on the emulator screen.

Default size: `W_DP=460`, `H_DP=260`.

---

## 15. Settings Persistence

`HudSettings` is stored in `SharedPreferences("hud_settings")`. All keys are defined as constants in `HudSettings.companion`. Loaded in `onCreate`, reloaded on `ACTION_APPLY_SETTINGS`.

Viewport mode is separately persisted in `SharedPreferences("phase0_viewport")` key `"mode"`. Runtime state (serviceRunning, minimapActive, blinkerActive) is persisted in `"phase0_runtime"` for boot restore.

## Lift-ready artifacts

### HudPresentation (inner class)
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostService.kt`
- **What:** android.app.Presentation subclass that owns the full HUD layer stack: filterWrapper+TextureView, mapBlocker, guidanceOverlay, speedcamOverlay, blinkerOverlay, rightEdgeMask. Lines 1410-1819.
- **Reuse:** Port onCreate/updateSurfaceLayout/applyHudFilter/showMap/hideMap directly. Replace GuidanceOverlayView and SpeedCamOverlayView with Flutter-rendered equivalents via FlutterTextureView or PlatformView. Keep filterWrapper+hardware-layer pattern exactly — applying setLayerType on TextureView directly does not work.

### selectHudDisplay()
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostService.kt`
- **What:** Three-priority display selection: exact displayId=2 → DISPLAY_CATEGORY_PRESENTATION → any non-default. Lines 994-999.
- **Reuse:** Copy verbatim. The constant HUD_DISPLAY_ID=2 is the Zeekr-validated value. Always use this priority ordering for display selection.

### IAppHostStub.computeViewportRect()
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/IAppHostStub.kt`
- **What:** Safe-area viewport computation for FULL_SCREEN / SQUARE_LEFT / SQUARE_RIGHT modes. Embeds SAFE_AREA_WIDTH_DP=616, SAFE_AREA_HEIGHT_DP=175, SAFE_AREA_OFFSET_X_DP=5, SAFE_AREA_OFFSET_Y_DP=6. Lines 220-253.
- **Reuse:** Port to Kotlin/Dart unchanged. The safe area constants are on-car calibrated values — do not change. For Flutter: call from the Kotlin host side to compute the Rect, then pass it to Flutter via MethodChannel as [left, top, right, bottom].

### createHudFilterPaint()
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostService.kt`
- **What:** Parametric ColorMatrix builder: monochrome-tinted contrast with hue passthrough and optional invert. Lines 1716-1783.
- **Reuse:** Port exactly for the Kotlin host layer. The default COLOR_PRESETS table in HudSettings is the operational set; use preset 0 (White, filterPreset=2, c=3.0, t=150, b=-20, huePass=1.0, hueAngle=290) as the starting point for new builds.

### HudSettings data class + COLOR_PRESETS
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/HudSettings.kt`
- **What:** All tunable HUD parameters with SharedPreferences serialization and ADB-broadcast merge logic. Lines 22-295.
- **Reuse:** Use as the canonical settings contract. applyFromBroadcast() can be kept as-is for ADB integration. The COLOR_PRESETS map defines the 5 validated filter bundles.

### HudVirtualDisplay
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/HudVirtualDisplay.kt`
- **What:** Emulator fallback: creates a VirtualDisplay backed by a floating TYPE_APPLICATION_OVERLAY TextureView window, so HudPresentation is testable without a physical display-2.
- **Reuse:** Include unchanged for emulator/dev testing. Default size W_DP=460, H_DP=260 gives a usable preview; adjust for the real HUD aspect ratio (1024:576) if desired.

### BlinkerOverlayView
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/BlinkerOverlayView.kt`
- **What:** Self-contained blinker: two amber dots positioned at safe-area offsets (-282dp / +292dp x, -60.5dp y), BCM polling via AdaptAPI reflection, 450ms blink cycle.
- **Reuse:** Port to new project. BCM function IDs BCM_LEFT=0x21051100, BCM_RIGHT=0x21051200 are Zeekr-specific. The dimens are final calibrated values.

### Safe area dimens.xml values
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/res/values/dimens.xml`
- **What:** On-car calibrated safe area: hud_bounds_width=616dp, hud_bounds_height=175dp, hud_bounds_offset_y=-8dp. Blinker dot positions: beautiful_dot_offset_x_left=-282dp, beautiful_dot_offset_x_right=292dp, beautiful_dot_offset_y=-60.5dp.
- **Reuse:** Copy these exact dp values into the new project's dimens.xml. They are locked values from physical HUD optics calibration.

### CarAppHostReceiver + action protocol
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostReceiver.kt`
- **What:** Broadcast-to-service bridge. Action com.zeekr.phase0.CARAPP_HOST with --es action start|stop|blinker_on|blinker_off|configure|screenshot. Full configurable key list at lines 117-127.
- **Reuse:** Adapt the broadcast action string and configurable key list for the new app package name. The configure action + applyFromBroadcast logic is the ADB tuning interface — keep for on-car tuning sessions.


## Concrete API surface

- android.app.Presentation(context, display)
- DisplayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
- DisplayManager.createVirtualDisplay(name, width, height, dpi, surface, VIRTUAL_DISPLAY_FLAG_PRESENTATION)
- Display.getMetrics(DisplayMetrics)
- TextureView.SurfaceTextureListener
- SurfaceTexture.setDefaultBufferSize(width, height)
- View.setLayerType(LAYER_TYPE_HARDWARE, paint)
- ColorMatrix(FloatArray)
- ColorMatrixColorFilter(ColorMatrix)
- Paint.colorFilter
- android.view.PixelCopy.request(Window, Bitmap, listener, handler)
- Window.setBackgroundDrawable(ColorDrawable(TRANSPARENT))
- Window.setFormat(PixelFormat.TRANSLUCENT)
- ISurfaceCallback.onSurfaceAvailable(Bundleable, callback)
- ISurfaceCallback.onVisibleAreaChanged(Rect, callback)
- ISurfaceCallback.onStableAreaChanged(Rect, callback)
- ISurfaceCallback.onSurfaceDestroyed(Bundleable, callback)
- IAppHost.Stub (setSurfaceCallback, invalidate, showToast, sendLocation)
- WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
- WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
- com.ecarx.xui.adaptapi.car.Car.create(context) [reflection]
- com.ecarx.xui.adaptapi.car.Car.getICarFunction() [reflection]
- ICarFunction.getFunctionValue(functionId) [reflection]
- BCM_LEFT=0x21051100
- BCM_RIGHT=0x21051200
- CarAppService.SERVICE_INTERFACE
- SessionInfoIntentEncoder.encode(SessionInfo(DISPLAY_TYPE_CLUSTER, ...))
- CarAppApiLevels.LEVEL_1
- HUD_DISPLAY_ID=2
- SharedPreferences hud_settings
- SharedPreferences phase0_viewport (key: mode)
- SharedPreferences phase0_runtime (keys: service_running, minimap_active, blinker_active)
- Broadcast action: com.zeekr.phase0.CARAPP_HOST
- Service actions: ACTION_START, ACTION_STOP, ACTION_SHOW_BLINKER, ACTION_HIDE_BLINKER, ACTION_APPLY_SETTINGS, ACTION_SET_MINIMAP_VIEWPORT, ACTION_SCREENSHOT, ACTION_BOOT_AUTOSTART
- SAFE_AREA_WIDTH_DP=616
- SAFE_AREA_HEIGHT_DP=175
- SAFE_AREA_OFFSET_X_DP=5
- SAFE_AREA_OFFSET_Y_DP=6
- DEFAULT_SQUARE_HEIGHT_FRACTION=0.9
- DEFAULT_SQUARE_EDGE_PADDING_DP=31
- RIGHT_EDGE_MASK_WIDTH_DP=40

## Risks

- TextureView hardware-layer invalidation: when filterWrapper.layerType==LAYER_TYPE_HARDWARE, the hardware layer caches composited output and does NOT automatically re-render when the SurfaceTexture updates. Must call filterWrapper.invalidate() in onSurfaceTextureUpdated — omitting this causes a frozen map frame under the color filter.
- setLayerType on TextureView itself: applying ColorMatrixColorFilter directly to a TextureView's layer type does NOT filter the SurfaceTexture content. The wrapper FrameLayout pattern is mandatory.
- Buffer oversampling and surface re-notification: setDefaultBufferSize on SurfaceTexture does not trigger onSurfaceTextureAvailable/onSurfaceTextureSizeChanged. The code manually calls surfaceEvents.onSurfaceReady after every setDefaultBufferSize call to notify YNavi of the new dimensions. Forgetting this causes YNavi to render at stale dimensions.
- displayId=2 is Zeekr-specific: on other hardware or firmware versions the HUD display may be at a different ID. The fallback chain (DISPLAY_CATEGORY_PRESENTATION → any non-default) provides a soft fallback but the hard-coded constant must be validated per platform.
- Presentation context vs. application context: all View constructors inside HudPresentation must use the Presentation's context (which carries the display's DisplayMetrics), not applicationContext. Using applicationContext causes incorrect dp→px conversion and wrong display density for the HUD.
- SYSTEM_ALERT_WINDOW required for virtual display fallback: on Android 10+ this permission requires explicit user grant via Settings or appops. The emulator path silently skips virtual display creation if the permission is missing.
- CarApp session teardown ordering: must call onAppPause → onAppStop → unbindService in that order before rebinding. Skipping onAppPause/onAppStop leaves YNavi's session in RESUMED state; the next onAppCreate will be rejected. A 2-second REBIND_DELAY_MS is needed for YNavi's async onDestroyLifecycle to complete.
- GuidanceOverlay scale pivot: overlayScale uses pivotX=0, pivotY=0 (top-left). If the scale changes while guidance bars are active, bars may momentarily render outside the viewport before the layout pass completes.
- minimapScale right-edge mask: the mask width is 40dp × minimapScale. If minimapScale is changed live without immediately calling updateSurfaceLayout, the mask may not cover the distance bar or may overlap map content.
- Boot auto-start race: the boot receiver fires on BOOT_COMPLETED when the display subsystem may not have enumerated display-2 yet. If selectHudDisplay() returns null, the VirtualDisplay fallback is used instead; the physical HUD display must be available before ensureHudPresentation() is called for the Presentation to land on it.
- AdaptAPI reflection (BCM signals): com.ecarx.xui.adaptapi.car.Car is a Zeekr system library loaded from the device image. It is not present on standard Android. The code fails gracefully (returns null, falls back to simulated signals) but live BCM polling will not work on non-Zeekr hardware.

## Open questions

- Does the new Flutter+Kotlin app host Flutter UI inside the HudPresentation (via FlutterTextureView or PlatformView), or does it use a separate FlutterEngine rendering into a second surface alongside the TextureView?
- Should the ColorMatrix filter be applied in Kotlin (hardware layer on filterWrapper) or replicated in Flutter (e.g., via ColorFiltered widget on the PlatformView)? The Kotlin hardware-layer approach is validated on-car.
- For the square viewport modes, should SQUARE_LEFT or SQUARE_RIGHT be the default? The on-car tests used both; driver preference may vary by steering-wheel side.
- The dimens.xml hud_bounds_offset_y is -8dp but IAppHostStub.SAFE_AREA_OFFSET_Y_DP is +6dp — these differ. Which value applies to the safe-area center vs. the bounds diagnostic overlay? Needs reconciliation.
- The VirtualDisplay emulator fallback renders at 460×260dp — the real HUD is 1024×576. Should the virtual display be created at the same aspect ratio (1024:576) to make emulator testing more representative?
- Is the 2-second REBIND_DELAY_MS after YNavi teardown sufficient on all firmware versions, or does it need to be configurable?
- Does the new app need to keep the SpeedCamOverlayView layer in the HudPresentation stack, or is that feature out of scope for the initial Flutter port?
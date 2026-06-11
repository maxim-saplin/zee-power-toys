# Knowledge: hud-overlays-blinker-guidance

## Phase0 HUD Overlay Implementations — Blinker and Guidance

### 1. Blinker — Two Distinct Variants

#### Variant A: Arrow Blinker (HudBlinkerActivity + activity_hud_blinker layout)
**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/HudBlinkerActivity.kt`
**Layout:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/res/layout/activity_hud_blinker.xml`

This is the "classic" arrow blinker, used as a standalone full-screen Activity on the HUD. The geometry:
- Both blinker ImageViews are **180dp × 180dp** (`R.dimen.blinker_size = 180dp`)
- **Left arrow** anchored `center_vertical | start`, margin-start **48dp** (`R.dimen.blinker_margin`)
- **Right arrow** anchored `center_vertical | end`, margin-end **48dp**
- Color: bright **hud_green `#00FF66`** when active; dim ghost at **alpha 0.2** with **hud_green_dim `#3300FF66`** when off
- Shape: SVG arrow pointing left/right — `ic_blinker_left.xml` / `ic_blinker_right.xml`
  - Left: `M110,10 L50,10 L20,30 L50,50 L110,50 L110,38 L70,38 L70,22 L110,22 Z` (viewport 120×60, reversed chevron/arrow pointing left)
  - Right: mirror: `M10,10 L70,10 L100,30 L70,50 L10,50 L10,38 L50,38 L50,22 L10,22 Z`
  - Both SVGs are 120dp wide × 60dp tall but rendered at 180×180dp (square bounding box)
  - Fill color is `#FFFFFFFF` (white) — tinted at runtime to `hud_green` via `android:tint`
- Blink rate: **500ms** (`BLINK_INTERVAL_MS = 500L`)
- Error indicator: small 8dp red oval (`hud_error_dot`) at `bottom|start` with 48dp margin
- Also has a center debug status bar with 4 LEDs (40dp each, 14dp gap): green/green/amber/white for left/right/hazard/blink

#### Variant B: "Beautiful" Dot Blinker (HudBeautifulBlinkerActivity + BlinkerOverlayView)
**Standalone Activity:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/HudBeautifulBlinkerActivity.kt`
**Embedded overlay:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/BlinkerOverlayView.kt`
**Layout:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/res/layout/activity_hud_beautiful_blinker.xml`

This is the "production" dot blinker that is also embedded into the CarApp HUD presentation (BlinkerOverlayView inside HudPresentation):
- Two dots, centered in the full display then offset via `translationX/Y`
- Dot size: **12dp** (`R.dimen.beautiful_indicator_dot = 12dp`)
- Left dot offset: X = **-282dp** (`beautiful_dot_offset_x_left`), Y = **-60.5dp** (`beautiful_dot_offset_y`)
- Right dot offset: X = **+292dp** (`beautiful_dot_offset_x_right`), Y = **-60.5dp** (same Y)
- Color: **amber `#FFC107`** (`hud_amber`), oval drawable (`hud_indicator_amber_dot.xml` — shape oval, solid `@color/hud_amber`)
- Blink: toggle alpha between 0.0 and 1.0 at **500ms** (standalone) or **450ms** (BlinkerOverlayView `BLINK_INTERVAL_MS = 450L`)
- Error indicator: 8dp red oval at `bottom|start`, 48dp margin (`beautiful_blinker_margin_side`)
- Black background with `clipChildren=true`
- **Hazard mode**: both dots blink simultaneously when `state.hazard == true` OR when `state.left && state.right`

**Asymmetric positioning note:** Left dot X = -282dp, right dot X = +292dp (not symmetric — 10dp asymmetry). These are translationX from a center-gravity anchor, so left dot sits further from center than right.

**BlinkerOverlayView** (embedded in HudPresentation, wired to `ACTION_SHOW_BLINKER` / `ACTION_HIDE_BLINKER`) uses `HandlerThread("HudBlinkerPoll")` at `Thread.MAX_PRIORITY`, polls every **50ms** when API OK, backs off to **1000ms** on failure. Reads AdaptAPI directly:
- `BCM_LEFT = 0x21051100`
- `BCM_RIGHT = 0x21051200`
- Via reflection: `com.ecarx.xui.adaptapi.car.Car.create(context)` → `getICarFunction()` → `getFunctionValue(functionId)`

### 2. Guidance Overlay (GuidanceOverlayView)
**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/GuidanceOverlayView.kt`

A `FrameLayout` overlaid on top of the CarApp `SurfaceView` inside `HudPresentation`. Two horizontal bars:

#### Top Bar (turn guidance)
LinearLayout, HORIZONTAL, `CENTER_VERTICAL`, padding 12dp H / 6dp V, gravity TOP.
- **turnArrowText** — Unicode arrow character, default 36sp + 8sp = 44sp (adjustable via `guidanceTextSizeSp + 8f`), `WHITE`, `DEFAULT_BOLD`
  - margin-end 8dp
- **turnDistanceText** — formatted distance string, default 28sp (`guidanceTextSizeSp`), `WHITE`, `DEFAULT_BOLD`
  - margin-end 12dp
- **turnCueText** — road name / cue, 18sp, semi-transparent white `argb(200, 255,255,255)`, maxLines=1, weight=1 (fills remaining)
- Background: `Color.argb(overlayBgAlpha, 0, 0, 0)` where default `overlayBgAlpha = 140`
- Position: `Gravity.TOP`, full-width

#### Bottom Bar (ETA)
LinearLayout, HORIZONTAL, `CENTER`, padding 12dp H / 6dp V, gravity BOTTOM.
- **remainDistText** — formatted distance to destination, 18sp (`etaTextSizeSp`), WHITE, BOLD, margin-end 16dp
- **remainTimeText** — remaining time "Xh Ymin" or "Y min", 18sp, semi-transparent white, margin-end 16dp
- **etaText** — arrival time "HH:MM", 18sp, WHITE, BOLD
- Background same semi-transparent black

Bars are hidden (`View.GONE`) until data arrives; hidden again via `clearGuidance()` when navigation ends.

#### Maneuver-to-Arrow Mapping (Unicode)
```
TYPE_TURN_NORMAL_LEFT / SLIGHT_LEFT  → "↰"
TYPE_TURN_SHARP_LEFT                 → "↲"
TYPE_TURN_NORMAL_RIGHT / SLIGHT_RIGHT → "↱"
TYPE_TURN_SHARP_RIGHT                → "↳"
TYPE_U_TURN_LEFT                     → "⤺"
TYPE_U_TURN_RIGHT                    → "⤻"
TYPE_STRAIGHT                        → "↑"
TYPE_ROUNDABOUT_CW                   → "⟳"
TYPE_ROUNDABOUT_CCW                  → "⟲"
TYPE_FERRY_BOAT/TRAIN                → "⛴"
TYPE_DESTINATION (all variants)      → "🏁"
TYPE_DEPART                          → "▶"
TYPE_UNKNOWN                         → "•"
default                              → "→"
On/off ramps inherit nearest left/right arrow
Fork/merge inherit nearest left/right arrow
```

#### Data Sources for Guidance
Two paths feed GuidanceOverlayView, both wired in `CarAppHostService.performHandshake()`:

1. **`updateFromTemplate(TemplateWrapper)`** — called when `IAppManager.getTemplate` returns a `NavigationTemplate`. Reads:
   - `NavigationTemplate.navigationInfo` (must be `RoutingInfo`)
   - `RoutingInfo.currentStep` → `Step.maneuver`, `Step.cue`
   - `RoutingInfo.currentDistance` → `Distance` (display value + unit enum)
   - `NavigationTemplate.destinationTravelEstimate` → `TravelEstimate` (remainingDistance, remainingTimeSeconds, arrivalTimeAtDestination)

2. **`updateFromTrip(Trip)`** — primary path; YNavi delivers `Trip` via `INavigationHost.updateTrip()`. Reads:
   - `Trip.steps[0]` → `Step.maneuver`, `Step.cue`, `Step.road`
   - `Trip.stepTravelEstimates[0].remainingDistance` → step distance
   - `Trip.destinationTravelEstimates[0]` → `TravelEstimate` (remainDist, remainTime, arrivalTime)
   - `Trip.currentRoad` → shown in cue field if cue is empty

Navigation lifecycle: `INavigationHost.navigationStarted()` / `navigationEnded()` → `setGuidanceActive(bool)` → shows/hides `mapBlocker` and calls `clearGuidance()` on end.

#### Distance Formatting
```kotlin
UNIT_METERS → "{int} m"
UNIT_FEET / UNIT_YARDS → "{int} ft/yd"
UNIT_KILOMETERS → "{decimal:1} km" (integer if whole)
UNIT_KILOMETERS_P1 → "{decimal:1} km"
UNIT_MILES → "{decimal:1} mi"
```

#### Duration Formatting
```
hours > 0 → "{h}h {m}min"
else      → "{m} min"
```

#### Arrival Time Formatting
`DateTimeWithZone` → Calendar in zone → `"HH:MM"` (24h format)

### 3. HudSettings — Overlay Knobs
**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/HudSettings.kt`

Fields relevant to the overlays:
| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `guidanceOverlay` | Boolean | true | Enable top guidance bar |
| `etaBar` | Boolean | true | Enable bottom ETA bar |
| `guidanceTextSizeSp` | Float | 28f | Distance/maneuver text size |
| `etaTextSizeSp` | Float | 18f | ETA bar text size |
| `overlayBgAlpha` | Int | 140 | Semi-transparent black background (0..255) |
| `guidanceModeOnly` | Boolean | false | Hide map, show only guidance |
| `overlayScale` | Float | 0.5 | Scale the overlay within viewport |

Overlay is scaled with `scaleX/Y = overlayScale` (default 0.5), pivoting at top-left, so the overlay's layout is sized at `viewport/overlayScale` to compensate and keep bars anchored to visual edges.

Settings persisted in `SharedPreferences("hud_settings")` and can be set live via ADB broadcast:
```
adb shell am broadcast -a com.zeekr.phase0.CARAPP_HOST \
  -n com.zeekr.phase0/.carapp.CarAppHostReceiver \
  --es action configure \
  --es guidance_overlay true \
  --es eta_bar true \
  --es guidance_text_size 28 \
  --es eta_text_size 18 \
  --es overlay_bg_alpha 140
```

### 4. Signal Architecture — BCM Turn Signals

**SignalState data class** (both activities share it):
```kotlin
data class SignalState(val left: Boolean, val right: Boolean, val hazard: Boolean)
```

**SignalStore** (`/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/harness/SignalStore.kt`): simulation store with SharedPrefs (`hud_signal_store`) holding `left`, `right`, `hazard`, `sim_enabled` booleans. Commands: "LEFT", "RIGHT", "HAZARD", "OFF".

**Real-car signal path (BlinkerOverlayView):** AdaptAPI reflection
- `com.ecarx.xui.adaptapi.car.Car.create(context)` → `getICarFunction()` → `getFunctionValue(BCM_LEFT/BCM_RIGHT)`
- `BCM_LEFT = 0x21051100`, `BCM_RIGHT = 0x21051200`
- Poll every 50ms when OK; 1s backoff on failure; MAX_PRIORITY thread

**HudBlinkerActivity / HudBeautifulBlinkerActivity proxy path:** `HudProxyClient` — binds to `ecarx.launcher3` package, service `com.zeekr.carlauncher.proxy.HudProxyService`, descriptor `com.zeekr.carlauncher.proxy.IHudProxy`, transacts `TRANSACTION_SIGNAL=3` with `signalId=0`. Reply Bundle keys: `"left"` (Int), `"right"` (Int), `"hazard"` (Int), may be nested under `"data"`. Poll every 150ms (Blinker) or 100ms (BeautifulBlinker).

REQUIREMENTS.md explicitly says "Only direct API calls, no reliance on Launcher proxy" — so the Flutter reimplementation should use only the AdaptAPI path (`BCM_LEFT/BCM_RIGHT` via `getICarFunction().getFunctionValue()`), not the proxy.

### 5. Emissive-on-Black Rendering Rules

The HUD projector emits no light for black pixels — black = transparent. Rules followed in phase0:
- All backgrounds: `android:color/black` or `Color.BLACK`
- All overlays: ARGB with `alpha < 255` only for semi-transparent black backgrounds (the guidance bars use `argb(140, 0,0,0)`)
- Blinkers: glow at alpha=1 (fully opaque amber/green), invisible at alpha=0 — **no fade, hard on/off**
- Error dot: 8dp fully opaque red (`hud_red = #FF3B30`) — emissive red dot when API fails
- HUD filter pipeline (for the map surface): `LAYER_TYPE_HARDWARE` on a `FrameLayout` wrapper of the `TextureView`, with a `ColorMatrixColorFilter` — contrast × threshold × color preset × brightness. This is for the YNavi map surface only; the guidance/blinker overlays are drawn on top of this filtered layer and are NOT themselves filtered.

### 6. HUD Safe Area Dimensions
From `dimens.xml`:
- HUD bounds: **616dp × 175dp** (`hud_bounds_width`, `hud_bounds_height`), Y offset -8dp
- Virtual display (emulator fallback): **460dp × 260dp** (`HudVirtualDisplay.W_DP/H_DP`)
- The "square safe area" is a fraction of the safe-area height: `squareSizeFraction = 0.9f`, `squarePaddingDp = 31f`

### 7. Service Control for Blinker
`CarAppHostService` (`CarAppHostService.kt:439-458`) handles:
- `ACTION_SHOW_BLINKER = "com.zeekr.phase0.carapp.action.SHOW_BLINKER"` → `presentation.showBlinker()` → `blinkerOverlay.visibility = VISIBLE; blinkerOverlay.startPolling()`
- `ACTION_HIDE_BLINKER = "com.zeekr.phase0.carapp.action.HIDE_BLINKER"` → `presentation.hideBlinker()` → `blinkerOverlay.stopPolling(); blinkerOverlay.visibility = GONE`
- Both persisted via `phase0_ui` prefs key `"blinker_running"` for boot restore

### 8. What Exists vs. What Is New (REQUIREMENTS delta)

| Feature | Phase0 Status | REQUIREMENTS asks for |
|---------|--------------|----------------------|
| Amber dot blinker | Exists — 12dp oval, X±282/292dp offsets from center, Y -60.5dp | Keep (it is the "dots" shape) |
| Arrow blinker | Exists — 180dp SVG arrows, hud_green tinted, 48dp margin from edges | This IS the "arrow shape" option |
| Smiley blinker | **NOT implemented** | New — "yellow smileys" shape |
| Blinker size control | Hardcoded in dimens | New — user-adjustable size |
| Blinker position control | Hardcoded offsets in dimens | New — user-adjustable position |
| Guidance overlay (turn arrow + distance + road name) | Exists — Unicode glyphs | Keep and port |
| ETA bar (remaining distance + time + arrival) | Exists | Keep and port |
| Battery level in HUD | **NOT in phase0** | New — "battery level and temp" |
| Steam Deck-style battery | **NOT in phase0** | New — specific visual style |
| Charging stats in HUD | **NOT in phase0** | New |
| HUD preview in UI | BlinkerActivity/BeautifulBlinkerActivity are diagnostic — no preview UI | New — grey-background HUD preview panel in Flutter UI |

### 9. Overlay Z-order in HudPresentation (CarAppHostService.kt:1514-1572)

Stack from bottom to top:
1. `filterWrapper` (TextureView with YNavi map + HUD color-matrix filter)
2. `mapBlocker` (solid black — hides map in guidance-only mode)
3. `guidanceOverlay` (GuidanceOverlayView)
4. `speedcamOverlay` (SpeedCamOverlayView)
5. `blinkerOverlay` (BlinkerOverlayView — initially GONE, shown via ACTION_SHOW_BLINKER)
6. `rightEdgeMask` (masks YNavi's distance bar if `hideDistanceBar=true`)

### 10. Blink Logic Detail

**applyVisuals / applyState logic** (identical across both activities and BlinkerOverlayView):
```kotlin
val hazard = state.hazard
val leftActive = hazard || (state.left && !hazard)   // hazard wins over solo left
val rightActive = hazard || (state.right && !hazard)  // hazard wins over solo right
leftDot.alpha  = if (blinkOn && leftActive)  1f else 0f
rightDot.alpha = if (blinkOn && rightActive) 1f else 0f
```
Hazard: both active simultaneously, same blink timer. The `!hazard` guard on solo-left/right means when hazard=true, only the hazard path sets both active — a subtle correctness detail.

BlinkerOverlayView (embedded) adds rising-edge/falling-edge optimization: only starts/stops the blinkRunnable when transitioning active→inactive or inactive→active, avoiding redundant timer resets on each poll.

## Lift-ready artifacts

### BlinkerOverlayView
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/BlinkerOverlayView.kt`
- **What:** Self-contained amber-dot blinker overlay (FrameLayout) that polls BCM turn signals via AdaptAPI reflection and drives two amber oval dots at hardcoded HUD-safe-area offsets. Includes blink timer (450ms), error indicator, and rising/falling edge optimization.
- **Reuse:** Port the BCM function IDs (BCM_LEFT=0x21051100, BCM_RIGHT=0x21051200), blink state machine, and applyVisuals logic directly to Flutter+Kotlin. Replace the hardcoded 12dp/±282dp/+292dp/-60.5dp with configurable parameters from the Flutter config. Replace Android views with Flutter CustomPainter shapes (oval for dots, arrow SVG for arrow variant, smiley path for the new variant). Keep the 450ms blink interval and edge-triggered timer start/stop.

### GuidanceOverlayView
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/GuidanceOverlayView.kt`
- **What:** Two-bar guidance overlay: top bar (Unicode turn arrow + distance + road cue) and bottom ETA bar (remaining distance + time + HH:MM arrival). Fed by either NavigationTemplate (from IAppManager.getTemplate) or Trip (from INavigationHost.updateTrip — primary path for YNavi).
- **Reuse:** Port the maneuverToArrow Unicode mapping table verbatim (30 maneuver types). Port formatDistance, formatDuration, formatArrival. In Flutter, implement as two Positioned widgets in a Stack anchored to top/bottom of the Safe Area viewport. Feed from the Trip updateTrip path — that is the primary YNavi data path. The GuidanceOverlayView.updateFromTrip fields map 1:1 to androidx.car.app.navigation.model.Trip fields exposed through the Kotlin CarApp host.

### HudSettings
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/HudSettings.kt`
- **What:** Complete settings schema for all HUD overlay parameters: guidance visibility, text sizes, background alpha, blinker geometry (squareSizeFraction, squarePaddingDp), minimap scale, filter pipeline parameters. Serialized to SharedPreferences. Includes COLOR_PRESETS map and ADB broadcast config API.
- **Reuse:** Use as the canonical list of configuration knobs to implement in Flutter ConfigStore. The guidanceOverlay, etaBar, guidanceTextSizeSp, etaTextSizeSp, overlayBgAlpha, overlayScale fields map directly to Flutter HUD overlay config. squareSizeFraction and squarePaddingDp define the safe-area square geometry. Do not port the HUD filter pipeline for YNavi map surface into the Flutter layer — that stays native.

### ic_blinker_left.xml + ic_blinker_right.xml
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/res/drawable/ic_blinker_left.xml`
- **What:** SVG vector paths for the arrow blinker shape. Left: reversed chevron/arrow. Right: mirror. Both 120×60 viewport, rendered at 180dp square in phase0.
- **Reuse:** Port the path data to Flutter CustomPainter Path or use a Flutter SVG widget. Scale dynamically based on user-configured blinker size. The path coordinates in a 120×60 viewport: Left arrow = M110,10 L50,10 L20,30 L50,50 L110,50 L110,38 L70,38 L70,22 L110,22 Z. Right arrow = M10,10 L70,10 L100,30 L70,50 L10,50 L10,38 L50,38 L50,22 L10,22 Z.

### SignalStore + SignalState
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/harness/SignalStore.kt`
- **What:** SharedPreferences-backed simulation store for blinker state (left/right/hazard booleans) with in-memory volatile state and string command API (LEFT/RIGHT/HAZARD/OFF). Used for T1/T2 simulation path.
- **Reuse:** Port to the CarSignals service fake/simulator in Flutter. The CarSignals service on T1/T2 should expose the same signal trio. The ADB broadcast inject path (SimulateReceiver) becomes the T2 native simulator broadcast injection mechanism.

### ICarHostStub (trip update wiring)
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/ICarHostStub.kt`
- **What:** INavigationHost.Stub that receives navigationStarted/navigationEnded lifecycle + updateTrip(Bundleable) from YNavi. Unpacks Trip, fires onTripUpdated callback to HudPresentation which forwards to GuidanceOverlayView.
- **Reuse:** This is the native Kotlin plumbing for the MinimapHost service in the new app. The Trip update callback chain (ICarHostStub → CarAppHostService.performHandshake lambda → HudPresentation.updateGuidanceFromTrip → GuidanceOverlayView.updateFromTrip) must be reimplemented. In Flutter architecture, the Kotlin side fires a method-channel event carrying the Trip fields; Flutter renders GuidanceOverlay as a Widget.


## Concrete API surface

- BCM_LEFT = 0x21051100 (AdaptAPI function ID, turn signal left)
- BCM_RIGHT = 0x21051200 (AdaptAPI function ID, turn signal right)
- com.ecarx.xui.adaptapi.car.Car.create(context) — reflection entry point
- Car.getICarFunction() — returns ICarFunction
- ICarFunction.getFunctionValue(functionId: Int): Int — reads BCM signal value
- INavigationHost.updateTrip(trip: Bundleable) — YNavi delivers Trip here
- INavigationHost.navigationStarted() / navigationEnded()
- androidx.car.app.navigation.model.Trip — primary guidance data object
- Trip.steps: List<Step> — turn steps, steps[0] is next maneuver
- Trip.stepTravelEstimates: List<TravelEstimate> — distance to each step
- Trip.destinationTravelEstimates: List<TravelEstimate> — total remaining
- Trip.currentRoad: CarText? — current road name
- TravelEstimate.remainingDistance: Distance
- TravelEstimate.remainingTimeSeconds: Long
- TravelEstimate.arrivalTimeAtDestination: DateTimeWithZone?
- Step.maneuver: Maneuver — type enum maps to Unicode arrow
- Step.cue: CarText? — road instruction text
- Maneuver.type: Int — Maneuver.TYPE_* constants
- Distance.displayDistance: Double
- Distance.displayUnit: Int — UNIT_METERS/KILOMETERS/MILES/FEET/YARDS/KILOMETERS_P1/MILES_P1
- CarAppHostService.ACTION_SHOW_BLINKER = com.zeekr.phase0.carapp.action.SHOW_BLINKER
- CarAppHostService.ACTION_HIDE_BLINKER = com.zeekr.phase0.carapp.action.HIDE_BLINKER
- HudSettings SharedPreferences name: hud_settings
- SignalStore SharedPreferences name: hud_signal_store
- ADB broadcast action: com.zeekr.phase0.CARAPP_HOST (configure settings)
- com.zeekr.phase0.PROXY_SIGNAL (broadcast from proxy path — do NOT use in new app per requirements)

## Risks

- Blinker dot positions (X: -282dp left, +292dp right, Y: -60.5dp) are calibrated to a specific HUD Safe Area size on the Zeekr DHU. These must be converted to Safe-Area-relative fractional coordinates so they work at any display resolution. The asymmetry (-282 vs +292) may be intentional HUD optic calibration — verify on-car before changing.
- The maneuverToArrow mapping uses Unicode characters (↰ ↱ ↲ ↳ ⤺ ⤻ ⟳ ⟲ ⛴ 🏁) — Flutter text rendering must select a font that covers these glyphs. Missing glyphs will fall back to tofu boxes. Consider a custom icon font or Flutter Path-based arrows for HUD reliability.
- The guidance overlay is scaled down to 0.5x (default overlayScale=0.5) from a layout 2× the viewport size, with pivot at (0,0). This means the semi-transparent background bars each occupy 50% of their 'logical' height. In Flutter, implement using Transform.scale with the same layout-larger-then-scale pattern, or equivalently shrink text sizes and bar heights proportionally.
- YNavi's primary Trip data path is updateTrip via INavigationHost (not getTemplate). Some navigation states only deliver data through one path. The new Flutter app must implement both paths (Trip updates and getTemplate fallback) to be robust, exactly as phase0 does.
- BCM AdaptAPI access requires the app to have system-level permissions that the phase0 diagnostic APK has as a system app. If the new Flutter app runs as a normal app, AdaptAPI reflection may fail silently. Confirm system app signature or permission grants before committing to direct AdaptAPI reads.
- The smiley blinker shape is entirely new — no reference implementation exists. Its visual design needs to be spec'd (size, expression, stroke vs fill, amber color) before the Flutter build agent can implement it.
- Blink rate differs between the embedded BlinkerOverlayView (450ms) and both standalone Activity classes (500ms). Flutter should canonicalize to one value — 450ms is more in sync with real car blinker cadence (~120 BPM = 500ms, but 450ms is the embedded/production value).
- The HUD filter pipeline (ColorMatrixColorFilter on the YNavi map TextureView) is NOT applied to the guidance or blinker overlays. Ensure the Flutter implementation keeps this separation — guidance/blinker widgets must be composited above the filtered map layer without inheriting the color matrix.
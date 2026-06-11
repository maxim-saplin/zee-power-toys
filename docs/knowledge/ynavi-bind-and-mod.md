# Knowledge: ynavi-bind-and-mod

## YNavi CarApp Host Bind Protocol and Mod Details

---

### 1. YNavi Package Name and Version

- **Package:** `ru.yandex.yandexnavi`
- **Base APK version:** 27.0.2 (`yandex-navigator-27-0-2.apk`)
- **Mod APK variants (current):**
  - `zeekr_signed_v10.apk` — Zeekr 007 preset (hud branch + main branch patches)
  - `deepal_signed_v10.apk` — Deepal S05 preset (hud branch not included by default)
- **Signing key:** AOSP debug key (`androiddebugkey.jks`, alias `platformkey`, v2 signature only)
- **Target service FQCN:** `ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService`

Source: `ynavi-zee/README.md:3`, `ynavi-zee/MINIMAP.md:7`, `ynavi-zee/WORKFLOW.md:119-130`

---

### 2. Service Binding — Intent / Action / Component

The host binds via the standard AndroidX Car App service action:

```kotlin
// CarAppHostService.kt:589-594
val bindIntent = Intent(CarAppService.SERVICE_INTERFACE).setComponent(
    ComponentName(
        "ru.yandex.yandexnavi",
        "ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService"
    )
)
context.bindService(bindIntent, connection, Context.BIND_AUTO_CREATE)
```

- **Service action string:** `androidx.car.app.CarAppService` (= `CarAppService.SERVICE_INTERFACE`)
- **Component:** `ru.yandex.yandexnavi/.projected.platformkit.presentation.service.NavigationCarAppService`
- **Manifest declaration** (`ynavi-zee/src/AndroidManifest.xml:502-513`):
  ```xml
  <service android:exported="true"
      android:foregroundServiceType="location"
      android:name="ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService">
      <intent-filter>
          <action android:name="androidx.car.app.CarAppService" />
          <category android:name="androidx.car.app.category.NAVIGATION" />
          <category android:name="androidx.car.app.category.FEATURE_CLUSTER" />
      </intent-filter>
      <intent-filter>
          <action android:name="ACTION_ROUTE_VARIANTS_SCREEN" />
      </intent-filter>
  </service>
  ```

The binding app needs `android.car.permission.TEMPLATE_RENDERER` permission (granted to `com.zeekr.phase0` on Zeekr OS).
Source: `zee_hud_2/phase0-diagnostics/app/src/main/AndroidManifest.xml:22`, `ynavi-zee/src/smali/i0/c.smali:7`

---

### 3. CarApp Handshake Protocol (AIDL / Binder)

After `onServiceConnected`, the IBinder is cast as `ICarApp`:

```kotlin
// CarAppHostService.kt:175
carApp = ICarApp.Stub.asInterface(service)
worker.execute { performHandshake(carApp ?: return@execute) }
```

#### Handshake sequence (all calls go through `IOnDoneCallback` with 10s timeout):

1. **`ICarApp.onHandshakeCompleted(HandshakeInfo, IOnDoneCallback)`**
   - Sends `HandshakeInfo(hostPackageName, CarAppApiLevels.LEVEL_1)`
   - Source: `CarAppHostService.kt:616-619`

2. **`ICarApp.onAppCreate(ICarHost, Intent, Configuration, IOnDoneCallback)`**
   - The `Intent` carries `CarAppService.SERVICE_INTERFACE` action, component set to the YNavi service
   - `SessionInfo(SessionInfo.DISPLAY_TYPE_CLUSTER, "phase0-cluster-<timestamp>")` is encoded into the intent via `SessionInfoIntentEncoder.encode()`
   - `Configuration` optionally has `UI_MODE_NIGHT_YES` set if `hudSettings.nightMode == true`
   - Source: `CarAppHostService.kt:623-644`

3. **`ICarApp.onAppStart(IOnDoneCallback)`**

4. **`ICarApp.onAppResume(IOnDoneCallback)`**

5. Optionally: **`ICarApp.onConfigurationChanged(Configuration, IOnDoneCallback)`** if night mode is active.

#### Stop sequence (ordered teardown is critical):
```kotlin
// CarAppHostService.kt:943-953
callWithTimeout("onAppPause") { cb -> target.onAppPause(cb) }
callWithTimeout("onAppStop") { cb -> target.onAppStop(cb) }
// wait 2000ms (REBIND_DELAY_MS) for YNavi destroy lifecycle
unbindService(connection)
```
The 2-second delay before unbind lets YNavi's `onDestroyLifecycle()` run so the next `onAppCreate` receives `ON_CREATE` not a stale lifecycle.

#### ICarHost stub — what the host provides to YNavi:
- `ICarHostStub` implements `ICarHost.Stub` and dispatches `ICarHost.getHost(type)`:
  - `"app"` → `IAppHostStub` (surface / viewport)
  - `"navigation"` → `INavigationHost.Stub` (trip data callbacks)
  - `"constraints"` → `IConstraintHost.Stub` (content limits, returns 100)
  - `"suggestion"` → `ISuggestionHost.Stub`
  - `"media_playback"` → `IMediaPlaybackHost.Stub`
- Source: `ICarHostStub.kt:79-90`

---

### 4. Surface Handover — How the Minimap Surface Is Obtained

After the CarApp lifecycle calls complete, YNavi calls back on the host's `IAppHost` binder:

```
YNavi → IAppHost.setSurfaceCallback(ISurfaceCallback)
```

`IAppHostStub.setSurfaceCallback()` stores the callback and calls `dispatchSurfaceAvailableIfPossible()`. When both the `ISurfaceCallback` and the `SurfaceContainer` are ready, it dispatches:

1. `ISurfaceCallback.onSurfaceAvailable(Bundleable<SurfaceContainer>, IOnDoneCallback)`
2. `ISurfaceCallback.onVisibleAreaChanged(Rect, IOnDoneCallback)` — full surface rect
3. `ISurfaceCallback.onStableAreaChanged(Rect, IOnDoneCallback)` — same rect

The `SurfaceContainer` is built from a `TextureView` in the `HudPresentation` on the secondary display:

```kotlin
// CarAppHostService.kt:884-893
override fun onSurfaceReady(surface: Surface, width: Int, height: Int, dpi: Int) {
    appHostStub.onSurfaceReady(
        SurfaceContainer(surface, width, height, dpi)
    )
}
```

The `TextureView`'s `SurfaceTexture.setDefaultBufferSize()` is used for buffer oversampling to control the map zoom level:

```kotlin
// CarAppHostService.kt:1587-1601
val scale = settings.minimapScale.coerceIn(0.25f, 1.0f)
val bufW = (viewport.width() / scale).roundToInt()
val bufH = (viewport.height() / scale).roundToInt()
textureView.surfaceTexture?.setDefaultBufferSize(bufW, bufH)
```

With `minimapScale=0.5`, the buffer is 2x the TextureView dimensions — YNavi renders more map area into the larger buffer, and the compositor scales it down, producing a "zoomed out" appearance.

**Critical gotcha:** `setSurfaceCallback` only fires reliably on YNavi's first cold-start per process. After a rebind without force-stopping, it may not fire again unless the session was properly destroyed. The fix currently is an ordered stop (onAppPause → onAppStop → unbind) with `REBIND_DELAY_MS=2000ms`.

Source: `IAppHostStub.kt:60-64`, `CarAppHostService.kt:884-915`, `YNAVI.md` §Detailed Runtime Flow

---

### 5. Trip Data Flow (Live Navigation Data)

YNavi calls `INavigationHost.updateTrip()` approximately every 1 second during active navigation:

```
YNavi NavigationCarAppService
  → INavigationHost.updateTrip(Bundleable)       [~1s interval]
    → ICarHostStub.navigationHostStub.updateTrip()
      → trip?.get() as? androidx.car.app.navigation.model.Trip
        → onTripUpdated callback (volatile function ref)
          → CarAppHostService.mainHandler.post
            → HudPresentation.updateGuidanceFromTrip(trip)
              → GuidanceOverlayView.updateFromTrip(trip)
```

Source: `ICarHostStub.kt:26-50`, `CarAppHostService.kt:604-608`

#### Trip object fields available:
```
Trip {
  steps: List<Step>
    [0].maneuver.type: Int        // e.g. 8 = TURN_NORMAL_RIGHT
    [0].cue: CarText              // street name
    [0].road: CarText             // road name
  stepTravelEstimates: List<TravelEstimate>
    [0].remainingDistance: Distance  // e.g. 110m
  destinations: List<Destination>
    [0].name: String              // destination address
  destinationTravelEstimates: List<TravelEstimate>
    [0].remainingDistance: Distance
    [0].remainingTimeSeconds: Long
    [0].arrivalTimeAtDestination: DateTimeWithZone
  currentRoad: CarText            // current street name
}
```

**Important:** YNavi always returns `MessageTemplate` from `getTemplate()` for cluster sessions — never `NavigationTemplate`. All structured navigation data flows exclusively through `updateTrip`. The template path is a dead end.

Source: `YNAVI.md` §Trip Data Pipeline, `ICarHostStub.kt:37-49`

Additionally:
- `INavigationHost.navigationStarted()` — called when YNavi begins a navigation session
- `INavigationHost.navigationEnded()` — called when navigation ends
- Source: `ICarHostStub.kt:27-31`

---

### 6. Required Permissions for the Host App

From `phase0-diagnostics/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.car.permission.TEMPLATE_RENDERER" />
<uses-permission android:name="androidx.car.app.NAVIGATION_TEMPLATES" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

The `TEMPLATE_RENDERER` permission must be pre-granted by the Zeekr OS (it is a system/signature permission).
Also requires: `<queries><package android:name="ru.yandex.yandexnavi" /></queries>` in manifest.
Source: `AndroidManifest.xml:4,22-23`

---

### 7. Compatible Mod Detection Strategy

There is **no explicit "mod version" marker** in the current codebase — the new Flutter app must implement its own detection. Based on source analysis, the recommended detection approach is:

#### Step 1 — Package presence check
```kotlin
// Equivalent to CarAppBindProbe.getPackageInfo()
packageManager.getPackageInfo("ru.yandex.yandexnavi", PackageManager.GET_SERVICES)
```
If absent → disable YNavi-in-HUD entirely.

#### Step 2 — Service declaration check
Check that `NavigationCarAppService` is declared:
```kotlin
// CarAppBindProbe.kt:35-39
packageInfo.services?.firstOrNull { info ->
    info.name == "ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService"
    || info.name.endsWith(".NavigationCarAppService")
}
```
Stock APK has this service, but it won't bind without the P1 allowlist bypass.

#### Step 3 — Actual bind attempt (runtime detection)
The most reliable detection is to attempt `bindService()` and check `onServiceConnected`. The `CarAppBindProbe` (4-second timeout) does exactly this:
```kotlin
// CarAppBindProbe.kt:61-65
val component = ComponentName(TARGET_PACKAGE, serviceName)
val bindIntent = Intent(CarAppService.SERVICE_INTERFACE).setComponent(component)
context.bindService(bindIntent, connection, Context.BIND_AUTO_CREATE)
```
If `bindService()` returns `false` or `onServiceConnected` is never called → stock APK (allowlist blocks non-whitelisted hosts).

#### Step 4 — Signature check (recommended for new app)
The modded APK is signed with the AOSP debug key. The new app can check:
```kotlin
val sig = packageManager.getPackageInfo("ru.yandex.yandexnavi", PackageManager.GET_SIGNING_CERTIFICATES)
// Check if signed with AOSP debug key vs. original YNavi release key
```
Stock YNavi is signed with Yandex's release key; mod is signed with AOSP debug key (`androiddebugkey.jks`). This is the most reliable static check.

#### REQUIREMENTS mandate: disable YNavi-in-HUD if no compatible mod
The new app must show a UI state "YNavi minimap unavailable — compatible mod not installed" if:
- Package not found, OR
- Package found but bind fails (SecurityException or returns false), OR
- (Recommended) Package found but signed with non-debug key (= stock Yandex release)

Source: `CarAppBindProbe.kt:17-166`, `MINIMAP.md` §P1, `YNAVI.md` §Why The Modded APK Is Needed

---

### 8. YNavi Mod Patch Inventory (hud branch, critical patches)

All patches are smali/resource edits applied via `apktool` on top of YNavi 27.0.2.

#### P1 — Host allowlist bypass
- **File:** `src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/presentation/service/NavigationCarAppService.smali:102-108`
- **Change:** Method `c()Li0/c;` patched to `return ALLOW_ALL_HOSTS_VALIDATOR` (`i0/c;->f`)
- **Effect:** Any app can bind without certificate validation
- **Without it:** `onServiceConnected` is never reached for non-whitelisted hosts

#### P2 — `android_auto_disabled` experiment bypass
- **File:** `src/smali_classes14/ru/yandex/yandexmaps/integrations/projected/n.smali`
- **Change:** Method `a()Z` returns `false` unconditionally (AA not disabled)
- **Effect:** Projection pipeline stays active regardless of server-side remote config

#### P3 — `ActionStrip` empty-list crash fix
- **File:** `src/smali/androidx/car/app/model/b.smali`
- **Change:** Method `b()` skip empty-action validation
- **Effect:** Prevents `IllegalStateException: Action strip must contain at least one action` crash when host calls `getTemplate()`

#### P4 — Lock screen elimination (two patches)
- **P4a:** `src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/presentation/protect/b.smali` — `a(Z)V` replaced with `return-void`
- **P4b:** `src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/presentation/protect/ScreenBlockActivity.smali` — `finish()` immediately in `onCreate()`
- **Effect:** YNavi no longer blocks Display 0 with "You are connected to Android Auto" screen when a host binds

#### P5 — KeepAliveService PendingIntent flag fix
- **File:** `src/smali_classes2/ru/yandex/yandexnavi/keepalive/KeepAliveService.smali`
- **Change:** Three `PendingIntent.getBroadcast()` calls changed from `FLAG_UPDATE_CURRENT | FLAG_CANCEL_CURRENT` to `FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE` (`0xc000000`)
- **Effect:** Prevents `IllegalArgumentException` on SDK 31+ (Zeekr runs SDK 32)

#### P6 — KeepAlive service rename + manifest alignment
- Renamed `AudioKeepAliveService` → `KeepAliveService`, changed FGS type `mediaPlayback` → `location|dataSync`
- **Files:** `AndroidManifest.xml`, `LaunchActivity.smali`, `MapActivity.smali`

#### P7 — Letterbox dimension tweak (Zeekr preset)
- **File:** `src/res/values/dimens.xml:4129-4131`
- Values: `zeeapp_letterbox_top=70dp`, `zeeapp_letterbox_bottom=10dp`, `zeeapp_letterbox_left=480dp`
- **Effect:** Pushes YNavi UI right to avoid Zeekr left-side panel overlap

#### P8 — GuidanceService cold-start crash loop fix
- **File:** `src/smali_classes2/ru/yandex/yandexnavi/keepalive/KeepAliveService.smali`
- **Change:** `ensureGuidanceStarted()` call removed from `onStartCommand()`
- **Effect:** Prevents repeating ANR cycle (`ForegroundServiceDidNotStartInTimeException`)

#### P9 — Yandex Plus paywall bypass (critical for non-Russian regions)
- **File:** `src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/domain/usecase/paywall/b.smali:158-161`
- **Change:** Method `a(paywall/b)` patched to always emit `HasPlus` (`ff3/k;->a`)
- **Effect:** Bypasses Plus subscription / country-availability gate that blocks `setSurfaceCallback` from ever firing outside Russia. Without this, binding succeeds but host never receives a surface.
- **Symptom without patch:** host lifecycle completes, `getTemplate()` returns `MessageTemplate` (`PLUS_COUNTRY_UNAVAILABLE`), `setSurfaceCallback` never fires.

Source: `MINIMAP.md` §Patch inventory P1–P9

---

### 9. Letterbox / Scale / Keepalive Specifics

#### Letterbox (MapActivity main display padding)
- Layout: `src/res/layout/maps_activity.xml` — FrameLayout replaced with vertical LinearLayout adding top/bottom spacers
- Build-time config via `features/config.env`:
  - `ZEEAPP_LETTERBOX_TOP_DIP` → `zeeapp_letterbox_top` in `dimens.xml` (Zeekr: 70dp)
  - `ZEEAPP_LETTERBOX_BOTTOM_DIP` → `zeeapp_letterbox_bottom` (Zeekr: 10dp)
  - `ZEEAPP_LETTERBOX_LEFT_DIP` → `zeeapp_letterbox_left` (Zeekr: 480dp — avoids left panel)
- Runtime night-mode theme repaint wired into `MapActivity.onConfigurationChanged()` for `uiMode` changes
- Source: `features/1.mapactivity_letterbox_padding.md`

#### UI Scale
- Build-time config: `ZEEAPP_UI_SCALE_PERCENT` → `zeeapp_ui_scale` fraction in `zeeapp_scaling.xml` (Zeekr: 175%)
- `ZEEAPP_MAP_SCALE_PERCENT` → `zeeapp_map_scale` (Zeekr: 130%)
- Applied in `ZeeUiScale.wrapBaseContext()` and `ZeeUiScale.applyMapScale()` via smali hooks in `AppCompat.attachBaseContext`, Application `attachBaseContext`, and `MapActivity.onCreate`
- Defensive: `densityDpi` fallback if ≤0, clamped to 120–960 range, try/catch for `IllegalStateException` on OEM ROMs
- Source: `features/2.app_ui_scale.md`, `src/res/values/zeeapp_scaling.xml`

#### Keepalive (Zeekr mode: fgs)
- **Mode:** `ZEEAPP_KEEPALIVE_ENABLED=1`, `ZEEAPP_KEEPALIVE_MODE=fgs`
- **Services:**
  - `ru.yandex.yandexnavi.keepalive.KeepAliveService` — `android:process=":persistent"`, `foregroundServiceType="location|dataSync"`
  - `ru.yandex.yandexnavi.keepalive.UiKeepAliveService` — main process, `foregroundServiceType="location|dataSync"`
- **Revival loop:** `BootKeepAliveReceiver` on boot, `AlarmManager` reassert via `KeepAliveTriggerReceiver` every ~60s
- **Passive location ticks:** `LocationManager` PendingIntent to `KeepAliveTriggerReceiver`
- **Started from:** `MapActivity.onCreate()` (launcher) and `LaunchActivity` (deep-link)
- Source: `features/3.fgs_keepalive.MD`

---

### 10. HUD Display and Viewport

- **HUD Display ID:** 2 (physical secondary display on Zeekr 007)
- **Display dimensions:** 1024×576 @ 213dpi
- **HUD optical safe area** (calibrated on-car): 616dp×175dp, center offset +5dp/+6dp
- **Viewport modes:** `full_screen`, `square_left`, `square_right`
- **Default:** 90% of safe-area height = ~210×210px square
- **Viewport rect computation:** `IAppHostStub.computeViewportRect()` — takes display dims, dpi, mode, sizeFraction, paddingDp
- **Presentation layer stack:** `filterWrapper(FrameLayout+hardware layer) > TextureView | mapBlockerView | GuidanceOverlayView | BlinkerOverlayView`

Source: `IAppHostStub.kt:199-263`, `YNAVI.md` §On-Car Learnings

---

### 11. Working Bind Strategy (Session Stability)

The `setSurfaceCallback` fires only on cold-start per YNavi process. The working sequence:

1. `pm clear ru.yandex.yandexnavi` (clears cached CarApp state)
2. Restore permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
3. Start YNavi standalone (launch via launcher or deep-link)
4. Start standalone navigation (deep-link + tap Go)
5. Bind host (Phase0 / new app) WITHOUT force-stopping YNavi
   → `setSurfaceCallback` fires, cluster renders on Display 2

On reconnect after disconnect: host schedules `attemptReconnect()` after `RECONNECT_DELAY_MS=5000ms`.
After binding died (force-stop): unbind + rebind after `RECONNECT_DELAY_MS`.
Manual restart (operator fallback): `BootActions.restartYNavi()` via `ActivityManager.forceStopPackage()`.

Source: `MINIMAP.md` §Working bind strategy, `CarAppHostService.kt:180-252`

---

### 12. Logcat Tags for Debug

- `Phase0CarHost` — all CarApp host events (bind, handshake, surface, trip data, settings)
- `Phase0Main` — MainActivity events

Key log lines to confirm successful bind:
```
Received ACTION_START
Presentation shown on displayId=...
onServiceConnected ... NavigationCarAppService
IAppHost.setSurfaceCallback callback=true
onSurfaceAvailable SUCCESS
```


## Lift-ready artifacts

### IAppHostStub
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/IAppHostStub.kt`
- **What:** IAppHost.Stub implementation. Stores ISurfaceCallback from YNavi, holds SurfaceContainer, dispatches onSurfaceAvailable/onVisibleAreaChanged/onStableAreaChanged. Contains MinimapViewportMode enum, computeViewportRect() static method with HUD safe-area constants, and setDefaultBufferSize oversampling logic.
- **Reuse:** Port directly into the new Kotlin Android module. computeViewportRect() with its HUD safe-area constants (616dp×175dp, +5dp/+6dp offset) should be preserved exactly. setSquareGeometry() and setMinimapViewportMode() are the primary runtime controls.

### ICarHostStub
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/ICarHostStub.kt`
- **What:** ICarHost.Stub implementation. Multiplexes getHost() to IAppHostStub (app), INavigationHost.Stub (navigation), IConstraintHost.Stub (constraints), ISuggestionHost.Stub, IMediaPlaybackHost.Stub. The INavigationHost.Stub.updateTrip() deserializes Trip objects and fires onTripUpdated callback.
- **Reuse:** Port directly. The getHost() dispatch map and INavigationHost.Stub.updateTrip() deserialization are production-tested and load-bearing. The onTripUpdated and onNavigationStateChanged callbacks are the data pipeline entry points for the guidance overlay.

### CarAppBindProbe
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/probes/CarAppBindProbe.kt`
- **What:** Diagnostic probe that checks YNavi package presence, NavigationCarAppService declaration, and performs an actual bindService() attempt with 4-second timeout. Returns ProbeResult with success/errorType/data.
- **Reuse:** Adapt as the mod-detection logic. The queryCarAppServices() + getPackageInfo() pattern for finding the service, and the bindService() + CountDownLatch timeout pattern are the key patterns. Use this to implement 'disable YNavi-in-HUD if no compatible mod installed' gating.

### CarAppHostService (binding + handshake section)
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostService.kt`
- **What:** The full foreground service that owns CarApp host lifecycle. Key methods: bindToNavigationCarApp(), performHandshake(), stopHosting(), attemptReconnect(). Constants: TARGET_PACKAGE, TARGET_SERVICE, REBIND_DELAY_MS=2000, RECONNECT_DELAY_MS=5000, CALL_TIMEOUT_MS=10000, HUD_DISPLAY_ID=2.
- **Reuse:** Port the performHandshake() sequence (onHandshakeCompleted with CarAppApiLevels.LEVEL_1, onAppCreate with DISPLAY_TYPE_CLUSTER SessionInfo, onAppStart, onAppResume) and the stopHosting() ordered teardown exactly. The ServiceConnection callbacks (onServiceConnected/onServiceDisconnected/onBindingDied) and reconnect logic are production-hardened.

### NavigationCarAppService smali (P1 allowlist bypass)
- **Source:** `/home/user/src/ynavi-zee/src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/presentation/service/NavigationCarAppService.smali`
- **What:** Patched smali for YNavi's CarApp service. Method c() at line 102-108 returns ALLOW_ALL_HOSTS_VALIDATOR (i0/c;->f) unconditionally, bypassing certificate host allowlist. This is the foundational patch enabling any app to bind.
- **Reuse:** Must be included in any modded YNavi APK build targeting Zee Power Toys as the host. The patch comment at line 105 and the sget-object/return-object pattern at 106-108 are the exact change. Without this patch, bindService() succeeds but onServiceConnected is never reached.

### paywall/b smali (P9 HasPlus bypass)
- **Source:** `/home/user/src/ynavi-zee/src/smali_classes5/ru/yandex/yandexnavi/projected/platformkit/domain/usecase/paywall/b.smali`
- **What:** Patched paywall use-case. Lines 158-161 always emit HasPlus state (ff3/k;->a singleton), bypassing the Yandex Plus subscription and country-availability gate that would otherwise prevent setSurfaceCallback from ever firing outside Russia.
- **Reuse:** Must be included in any build for Zeekr (non-Russian region). Without P9, the binding and lifecycle succeed but setSurfaceCallback never fires because PLUS_COUNTRY_UNAVAILABLE MessageTemplate is pushed instead of the navigation surface screens.

### BootActions
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/boot/BootActions.kt`
- **What:** Singleton with restartYNavi() (via ActivityManager.forceStopPackage reflection), startCarAppHost(), addDozeWhitelist() (via IDeviceIdleController reflection). YNAVI_PACKAGE constant = 'ru.yandex.yandexnavi'.
- **Reuse:** Port restartYNavi() and addDozeWhitelist() patterns. The reflection-based forceStopPackage requires FORCE_STOP_PACKAGES permission (system/signature level on Zeekr). The addDozeWhitelist pattern via IDeviceIdleController.addPowerSaveWhitelistApp is the correct approach on this platform.

### zeeapp_scaling.xml + ZeeUiScale smali
- **Source:** `/home/user/src/ynavi-zee/src/res/values/zeeapp_scaling.xml`
- **What:** Resource file defining zeeapp_ui_scale (175%) and zeeapp_map_scale (130%) fraction values for the Zeekr preset. Consumed by ZeeUiScale.smali helper class in the mod APK.
- **Reuse:** These values are build-time parameters. When building a new mod APK variant, set via features/config.env (ZEEAPP_UI_SCALE_PERCENT=175, ZEEAPP_MAP_SCALE_PERCENT=130). The ZeeUiScale.wrapBaseContext/applyToConfiguration/applyMapScale smali methods apply these at runtime.

### dimens.xml letterbox values
- **Source:** `/home/user/src/ynavi-zee/src/res/values/dimens.xml`
- **What:** Contains zeeapp_letterbox_top=70dp, zeeapp_letterbox_bottom=10dp, zeeapp_letterbox_left=480dp at lines 4129-4131 for the Zeekr 007 preset.
- **Reuse:** These values encode the Zeekr 007 display geometry (480dp left panel, 70dp top system bar, 10dp bottom). Set via features/config.env before build. Apply_feature_config.py injects them into this file. The 480dp left margin is specific to Zeekr 007's persistent left-side panel.


## Concrete API surface

- CarAppService.SERVICE_INTERFACE (action: androidx.car.app.CarAppService)
- ru.yandex.yandexnavi (package name)
- ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService (component)
- ICarApp.Stub.asInterface(IBinder)
- ICarApp.onHandshakeCompleted(Bundleable<HandshakeInfo>, IOnDoneCallback)
- ICarApp.onAppCreate(ICarHost, Intent, Configuration, IOnDoneCallback)
- ICarApp.onAppStart(IOnDoneCallback)
- ICarApp.onAppResume(IOnDoneCallback)
- ICarApp.onAppPause(IOnDoneCallback)
- ICarApp.onAppStop(IOnDoneCallback)
- ICarApp.onConfigurationChanged(Configuration, IOnDoneCallback)
- ICarApp.getManager(String, IOnDoneCallback) — types: 'app', 'navigation'
- ICarHost.Stub — getHost(String) returning IBinder for 'app', 'navigation', 'constraints', 'suggestion', 'media_playback'
- IAppHost.Stub — setSurfaceCallback(ISurfaceCallback)
- IAppHost.Stub — invalidate()
- ISurfaceCallback.onSurfaceAvailable(Bundleable<SurfaceContainer>, IOnDoneCallback)
- ISurfaceCallback.onVisibleAreaChanged(Rect, IOnDoneCallback)
- ISurfaceCallback.onStableAreaChanged(Rect, IOnDoneCallback)
- ISurfaceCallback.onSurfaceDestroyed(Bundleable<SurfaceContainer>, IOnDoneCallback)
- INavigationHost.Stub — updateTrip(Bundleable<Trip>)
- INavigationHost.Stub — navigationStarted()
- INavigationHost.Stub — navigationEnded()
- IConstraintHost.Stub — getContentLimit(Int): Int
- IConstraintHost.Stub — isAppDrivenRefreshEnabled(): Boolean
- HandshakeInfo(hostPackageName, CarAppApiLevels.LEVEL_1)
- SessionInfo(SessionInfo.DISPLAY_TYPE_CLUSTER, sessionId)
- SessionInfoIntentEncoder.encode(SessionInfo, Intent)
- SurfaceContainer(Surface, width, height, dpi)
- SurfaceTexture.setDefaultBufferSize(width, height) — buffer oversampling for map zoom
- android.car.permission.TEMPLATE_RENDERER
- androidx.car.app.NAVIGATION_TEMPLATES
- androidx.car.app.category.NAVIGATION (intent-filter category)
- androidx.car.app.category.FEATURE_CLUSTER (intent-filter category)
- IAppManager.startLocationUpdates(IOnDoneCallback)
- IAppManager.getTemplate(IOnDoneCallback)
- ActivityManager.forceStopPackage(String) — via reflection for YNavi restart
- IDeviceIdleController.addPowerSaveWhitelistApp(String) — via reflection for Doze whitelist
- i0/c;->f — ALLOW_ALL_HOSTS_VALIDATOR singleton (smali field, NavigationCarAppService P1 patch target)
- ff3/k;->a — HasPlus state singleton (smali field, paywall/b P9 patch target)
- ru.yandex.yandexnavi.keepalive.KeepAliveService
- ru.yandex.yandexnavi.keepalive.UiKeepAliveService
- ru.yandex.yandexnavi.keepalive.BootKeepAliveReceiver
- ru.yandex.yandexnavi.keepalive.KeepAliveTriggerReceiver
- zeeapp_letterbox_top / zeeapp_letterbox_bottom / zeeapp_letterbox_left (dimen resources in YNavi mod)
- zeeapp_ui_scale / zeeapp_map_scale (fraction resources in YNavi mod, zeeapp_scaling.xml)
- com.zeekr.phase0.CARAPP_HOST (broadcast action for ADB control)
- com.zeekr.phase0.carapp.action.START / STOP / APPLY_SETTINGS / SHOW_BLINKER / HIDE_BLINKER (service actions)

## Risks

- setSurfaceCallback fires only on YNavi's first cold-start per process. On rebind without force-stop, it may not re-fire. The ordered teardown (onAppPause→onAppStop→unbind) + 2s REBIND_DELAY_MS mitigates this, but still requires operator restart as fallback. A smali patch to rd3/u.smali could fix this permanently.
- P9 (Yandex Plus paywall bypass) is critical outside Russia. Without it, binding succeeds, lifecycle completes, but setSurfaceCallback never fires — host sees no surface, no HUD output. Symptom is indistinguishable from other failures without knowing to check getTemplate() response type.
- The TEMPLATE_RENDERER permission (android.car.permission.TEMPLATE_RENDERER) is a system/signature permission. If the new app is not pre-granted by Zeekr OS, binding will fail with SecurityException. Verify permission grant at install time.
- Stock YNavi is signed with Yandex release key; modded APK is signed with AOSP debug key. Installing modded APK requires -d flag (downgrade/debug). Re-signing may trigger YNavi's own runtime integrity checks — smali stubs may be needed if signature verification is enforced at runtime.
- No explicit mod version marker exists in the current codebase. The new app has no static way to verify 'this is the correct HUD-patched mod version'. Bind attempt is the only reliable runtime check. If Yandex releases a new YNavi version, all smali patches must be re-applied (paths may have changed due to obfuscation churn).
- On-car cold-boot: YNavi MapKit may fail DNS resolution if internet is not ready when the process starts. Phase0 works around this by waiting for validated internet (ConnectivityManager) then force-restarting YNavi. The new app must implement the same boot-time network-readiness gate.
- KeepAliveService P8 patch (removed ensureGuidanceStarted() from onStartCommand) was discovered only on-car — emulator does not reproduce the ANR loop. Any new mod build must carry P8, especially for Zeekr where the OS aggressively kills the main process while :persistent survives.
- P3 (ActionStrip crash fix) is in androidx.car.app.model.b.smali — this is AndroidX library code bundled inside YNavi. If YNavi upgrades its AndroidX Car App dependency, this obfuscated class name may change and the patch path will be stale.
- REBIND_DELAY_MS=2000ms and RECONNECT_DELAY_MS=5000ms are empirically determined timing constants. If YNavi's destroy lifecycle takes longer on real hardware or slower ROM builds, these may need adjustment.
- Guidance overlay offset issue (ISSUE_WITH_GUIDANCE_OFFSETS.md): the right-side speed/limit cluster on YNavi's own main-display UI does not respect letterbox offsets via XML or inset patches. Only the left ETA panel was fixed. If guidance overlay position matters on YNavi's own screen, smali-level FluidContainer/NaviGuidanceIntegrationController hooks are needed.
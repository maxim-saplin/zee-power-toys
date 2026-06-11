# Knowledge: boot-fgs-apibrowser-diagnostics

## Boot / Auto-launch / Foreground Service Pattern

### Overview

The boot/FGS architecture is a two-layer hand-off: a lightweight `BroadcastReceiver` receives `BOOT_COMPLETED` from the OS and immediately delegates all real work to `CarAppHostService` (a full `Service`) via `startForegroundService()`. This means the actual restore sequence (Doze whitelist, cluster locale push, HUD state restore) runs inside a foreground service whose process cannot be killed, with no wake locks or alarm managers required.

---

### Layer 1 — BootNetworkWatchdog (BroadcastReceiver)

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/boot/BootNetworkWatchdog.kt`

```kotlin
class BootNetworkWatchdog : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_AUTO_START, true)
        if (!enabled) return
        val serviceIntent = Intent(appContext, CarAppHostService::class.java).apply {
            action = CarAppHostService.ACTION_BOOT_AUTOSTART
        }
        appContext.startForegroundService(serviceIntent)
    }
    companion object {
        const val PREFS_NAME = "phase0_ui"
        const val KEY_AUTO_START = "auto_start_on_boot"
    }
}
```

**Key design points:**
- No work is done in the receiver — it only checks a SharedPreferences flag (`phase0_ui` / `auto_start_on_boot`, default `true`) and fires `startForegroundService()`.
- No wake lock is acquired; the FGS provides the process keep-alive needed.
- `directBootAware="false"` in manifest — the receiver only fires after credential unlock, not in direct-boot mode (appropriate since AdaptAPI requires full user context).

**Manifest registration** (`AndroidManifest.xml` line 69–75):
```xml
<receiver
    android:name=".boot.BootNetworkWatchdog"
    android:exported="true"
    android:directBootAware="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

Required permission: `android.permission.RECEIVE_BOOT_COMPLETED`.

---

### Layer 2 — CarAppHostService (Foreground Service)

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/CarAppHostService.kt`

The service handles `ACTION_BOOT_AUTOSTART` in `onStartCommand()` (line 491–493) by calling `runBootAutostart()` on its single-thread `worker` executor:

```kotlin
ACTION_BOOT_AUTOSTART -> {
    Log.i(TAG, "Received ACTION_BOOT_AUTOSTART — running boot restore sequence in foreground service")
    runBootAutostart()
}
```

**`runBootAutostart()` sequence** (lines 1245–1326):

1. Reads `blinker_running` flag from `phase0_ui` prefs.
2. Calls `BootActions.addDozeWhitelist(ctx)` — adds YNavi package to Doze whitelist via reflection on `IDeviceIdleController`.
3. Calls `BootActions.pushClusterLocaleEnglish(ctx)` — sets cluster locale function `0x20318a00` to English (value `1`) via AdaptAPI reflection, up to 3 retries with 1 s delay.
4. Sends itself `ACTION_START` intent (with persisted viewport mode from `phase0_ui/viewport_mode`) to trigger YNavi CarApp binding.
5. Optionally sends `ACTION_SHOW_BLINKER` if `blinker_running` was persisted true.

**Service FGS declaration** (manifest line 115–118):
```xml
<service
    android:name=".carapp.CarAppHostService"
    android:exported="true"
    android:foregroundServiceType="dataSync|location" />
```

`foregroundServiceType="dataSync|location"` is required on Android 14+ for services that request GPS updates.

**`onCreate()` sequence** (no boot-specific, runs every service start):
- Calls `startForeground(NOTIF_ID=1001, buildNotification())` immediately.
- Creates notification channel `"phase0_carapp_host"` (IMPORTANCE_LOW).
- Loads `HudSettings` from SharedPreferences.
- Restores `minimapViewportMode` from `phase0_viewport/mode`.
- Wires `SpeedCamProximityMonitor` callbacks.
- Registers GPS updates via `LocationManager`.
- Prunes stale speed cameras (>90 days) asynchronously.
- Registers `SpeedCamDataReceiver` at **runtime** (not manifest) — critical for Android 12+ implicit broadcast restriction.
- Optionally creates PIP overlay if `SYSTEM_ALERT_WINDOW` is granted.

**Runtime state persistence** (`phase0_runtime` SharedPreferences):
- `service_running` (Boolean)
- `minimap_active` (Boolean)
- `blinker_active` (Boolean)

**Service actions (all sent via `startForegroundService()`):**

| Action constant | Value | Purpose |
|---|---|---|
| `ACTION_START` | `com.zeekr.phase0.carapp.action.START` | Start minimap, bind to YNavi |
| `ACTION_STOP` | `com.zeekr.phase0.carapp.action.STOP` | Stop minimap, unbind |
| `ACTION_BOOT_AUTOSTART` | `com.zeekr.phase0.carapp.action.BOOT_AUTOSTART` | On-boot restore sequence |
| `ACTION_SHOW_BLINKER` | `com.zeekr.phase0.carapp.action.SHOW_BLINKER` | Show blinker overlay in HUD |
| `ACTION_HIDE_BLINKER` | `com.zeekr.phase0.carapp.action.HIDE_BLINKER` | Hide blinker overlay |
| `ACTION_SET_MINIMAP_VIEWPORT` | `...SET_MINIMAP_VIEWPORT` | Change viewport mode live |
| `ACTION_APPLY_SETTINGS` | `...APPLY_SETTINGS` | Apply HudSettings changes |
| `ACTION_TEST_SPEEDCAM` | `...TEST_SPEEDCAM` | Test speedcam HUD alert |
| `ACTION_SPEEDCAM_STATUS_DUMP` | `...SPEEDCAM_STATUS_DUMP` | Dump diagnostics to Logcat |
| `ACTION_SPEEDCAM_DB_CLEAR` | `...SPEEDCAM_DB_CLEAR` | Clear speedcam DB |
| `ACTION_RESTART_YNAVI_SILENT` | `...RESTART_YNAVI_SILENT` | Force-stop + restart YNavi |
| `ACTION_SCREENSHOT` | `...SCREENSHOT` | Capture HUD screenshot |

**Extras:**
- `EXTRA_MINIMAP_VIEWPORT_MODE` = `"extra_minimap_viewport_mode"`: string, one of `"full_screen"` / `"square_left"` / `"square_right"`.
- `EXTRA_STARTUP_BIND_DELAY_MS` = `"extra_startup_bind_delay_ms"`: long string, default `0L`.

**`START_STICKY`** is returned from `onStartCommand()` — the OS will restart the service if killed.

---

### BootActions (shared helpers)

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/boot/BootActions.kt`

All methods safe to call on any thread; callbacks are posted to main thread.

```kotlin
object BootActions {
    const val YNAVI_PACKAGE = "ru.yandex.yandexnavi"
    const val LOCALE_FUNC_ID = 0x20318a00
    const val LOCALE_ENGLISH = 1
    const val LOCALE_RETRY_COUNT = 3
    const val LOCALE_RETRY_DELAY_MS = 1000L

    fun runOnBoot(context: Context, callback: StatusCallback? = null)   // calls run()
    fun runOnLaunch(context: Context, callback: StatusCallback? = null) // same

    fun addDozeWhitelist(context: Context): Boolean // adds YNavi to IDeviceIdleController whitelist
    fun pushClusterLocaleEnglish(context: Context): Boolean  // writes 0x20318a00=1 via AdaptAPI
    fun startCarAppHost(context: Context): Boolean  // startForegroundService(CarAppHostService, ACTION_START)
    fun restartYNavi(context: Context): Boolean     // ActivityManager.forceStopPackage("ru.yandex.yandexnavi")
}
```

`addDozeWhitelist`: uses `Class.forName("android.os.IDeviceIdleController$Stub")` + `ServiceManager.getService("deviceidle")` reflection. Requires `DEVICE_POWER` permission (system-level on Zeekr DHU).

`pushClusterLocaleEnglish`: uses `Car.create(context)` → `getICarFunction()` → `setFunctionValue(0x20318a00, 1)`. Fire-and-forget write; read-back may return 255 (undefined) even on success — only write return is checked.

---

### Auto-start toggle in MainActivity

**File:** `MainActivity.kt` lines 453–460, 1647–1659

SharedPreferences file: `phase0_ui`, key: `auto_start_on_boot` (Boolean, default `true`).
On app launch with flag=true, `runAutoStartActions()` → `BootActions.runOnLaunch(this, callback)` is called immediately.

---

## AP (AdaptAPI) Browser — Catalog, Reader, Pinning Model

### Signal Catalog

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiCatalog.kt`

Three API source types:
```kotlin
enum class ApiSource { ADAPT_SENSOR, ADAPT_FUNCTION, CAR_PROPERTY }
```

Six signal groups:
```kotlin
enum class SignalGroup(val title: String) {
    BATTERY("Battery & Energy"),
    MOTION("Motion"),
    CHARGING("Charging"),
    BODY("Body & Lights"),
    TIRES("Tires (TPMS)"),
    AOSP("AOSP CarProperty")
}
```

`SignalDef` data class:
```kotlin
data class SignalDef(
    val label: String,
    val hexId: Int,      // hex address for AdaptAPI / AOSP property ID
    val source: ApiSource,
    val group: SignalGroup,
    val unit: String = "",
)
```

`MetricValue` data class (runtime read result):
```kotlin
data class MetricValue(
    val def: SignalDef,
    val raw: Any?,       // Float (sensors), Int (functions/AOSP), Boolean
    val formatted: String,
    val changed: Boolean,  // true when raw differs from previous read
    val pinned: Boolean
)
```

**Full signal list (51 signals across 6 groups):**

BATTERY (14 signals): Battery SoC `0x00404000`%, Battery Level `0x00100A00`%, Battery Temp `0x00102A00`°C, Battery State `0x00201500`, Battery Color `0x00104000`, Range Total `0x00100800`km, Range EV `0x00101900`km, Range Dynamic `0x00101B00`km, Discharge Power `0x00103600`kW, Discharge Limit `0x00103500`kW, Energy Cons 1 `0x00103100`kWh/100km, Energy Cons 2 `0x00103200`, Aux DCDC Voltage `0x00103300`V, Aux DCDC Load `0x00103400`.

MOTION (4 signals): Speed `0x00100100`m/s, Gear `0x00200500`, Brake Pedal `0x00101300`%, Accelerator Pedal `0x00101400`%.

CHARGING (19 signals): Power Flow `0x24010100`, Power Flow HEV `0x24010200`, Hybrid SoC `0x24010500`%, Charging SoC `0x24100200`%, Discharging SoC `0x24100100`%, Charging Plug Type `0x24130100`, Charging Plug State `0x24130200`, Charging Voltage `0x24140100`V, Charging Current `0x24140200`A, Charging Power `0x241E0500`kW, Charging Power live `0x2420C000`kW, Charging Est. Time `0x24120300`min, Charging Speed `0x24120400`km/h, Charging Energy `0x24120500`kWh, Charge/Discharge Status `0x241D2500`, Energy Regen Mode `0x20020500`, Regen Bar A `0x24215C00`, Regen Bar B `0x241E5000`, E-Pedal `0x20180100`.

BODY (13 signals): Door State `0x21050100`, Tailgate Position `0x21110100`, Tailgate % `0x21110200`, Drive Mode `0x22010100`, Track/Race Switch `0x22060100`, DIM Theme `0x22040100`, DIM Theme Sync `0x22040000`, Day Mode Setting `0x20150100`, Theme DIM `0x29020D00`, Theme HUD `0x29020C00`, Blinker Left `0x21051100`, Blinker Right `0x21051200`, Blinker Hazard `0x21050F00`.

TIRES (4 signals, ADAPT_SENSOR): Tire FL `0x00500100`bar, FR `0x00500200`, RL `0x00500300`, RR `0x00500400`.

AOSP CarProperty (12 signals): Turn Signal State `0x11400408`, Hazard Lights State `0x11400E03`, EV Battery Level `0x11600309`%, EV Charge Rate `0x1160030C`, Range Remaining `0x11600308`km, Battery Capacity `0x11600106`kWh, Vehicle Speed `0x11600207`m/s, Current Gear `0x11400401`, Gear Selection `0x11400400`, Charge Port Connected `0x1120050B`, Charge Port Open `0x1120050A`, Fuel Level `0x11600307`.

`CarApiCatalog.grouped` is a lazily-computed `List<Pair<SignalGroup, List<SignalDef>>>` sorted by `SignalGroup.entries` order.

---

### CarApiReader

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiReader.kt`

Manages two API connections simultaneously:

1. **AdaptAPI** via `com.ecarx.xui.adaptapi.car.Car.create(context)` → `.getSensorManager()` + `.getICarFunction()`.
2. **AOSP Car** via `android.car.Car.createCar(context, null)` → `.getCarManager("property")`.

Both use `ReflectionUtils` to avoid compile-time dependency on private system APIs.

```kotlin
fun connect()     // tries both APIs silently; sensorMgr != null OR propertyMgr != null = isConnected
fun disconnect()  // calls disconnect() on both Car instances
fun readAll(catalog: List<SignalDef>, previous: Map<Int, Any?>): List<MetricValue>
fun readSubset(catalog: List<SignalDef>, pinnedIds: Set<Int>, previous: Map<Int, Any?>): List<MetricValue>
```

Read dispatch by `ApiSource`:
- `ADAPT_SENSOR`: tries `getSensorLatestValue(id)` first, falls back to `getSensorEvent(id)`. Returns `Float?`. Guards against `Float.MIN_VALUE` as sentinel for "no data".
- `ADAPT_FUNCTION`: calls `getFunctionValue(id)`. Returns `Int?`.
- `ADAPT_FUNCTION` float variant: `getCustomizeFunctionValue(functionId, zone=0)`. Returns `Float?`.
- `CAR_PROPERTY`: dispatches by upper bits of property ID:
  - `0x00400000` → `getIntProperty(id, 0)` (INT type)
  - `0x00600000` → `getFloatProperty(id, 0)` (FLOAT type)
  - `0x00200000` → `getBooleanProperty(id, 0)` (BOOLEAN type)

Format logic in `CarApiReader.format(def, raw)`:
- `Float` → `"%.1f"` + unit
- `Int` / `Boolean` / `Number` → `.toString()` + unit
- `null` → `"—"`

---

### PinnedMetricsStore

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/PinnedMetricsStore.kt`

SharedPreferences file: `"pinned_metrics"`, key: `"ids"`.

Stores pinned signal `hexId` values as a `Set<String>` (integers serialized to strings) — AOSP `SharedPreferences.putStringSet` doesn't support `Set<Int>` directly.

```kotlin
object PinnedMetricsStore {
    fun load(ctx: Context): Set<Int>             // deserializes "ids" to Set<Int>
    fun save(ctx: Context, ids: Set<Int>)        // serializes to Set<String>
    fun toggle(ctx: Context, hexId: Int): Boolean  // atomically toggles one ID, returns new pinned state
}
```

---

### ApiBrowserActivity — Poll Loop

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/ApiBrowserActivity.kt`

- Creates `CarApiReader` and connects in `onStart()`.
- Disconnects and quits poll thread in `onStop()`.
- Poll interval: `500L` ms on a `HandlerThread("ApiBrowserPoll")`.
- Grid layout: 2 columns (`SPAN_COUNT = 2`), headers span full width.
- UI scale: `1.75f` density override in `attachBaseContext()` (for car touchscreen readability).
- Pin toggle: `PinnedMetricsStore.toggle(ctx, def.hexId)` → toolbar subtitle updates with pin count.
- Previous values map drives `MetricValue.changed` field which bolds the value text in the adapter.

**Poll runnable pattern:**
```kotlin
val values = r.readAll(catalog, previousValues)
previousValues = values.associate { it.def.hexId to it.raw }
mainHandler.post { adapter.update(values, pinned) }
pollHandler?.postDelayed(this, POLL_INTERVAL_MS)
```

---

### ApiBrowserAdapter

**File:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/ApiBrowserAdapter.kt`

Two item types: `Item.Header(group: SignalGroup)` and `Item.Metric(value: MetricValue)`.
- Headers: full-width section titles from `group.title`.
- Metrics: label, formatted value (bolded if changed), hex ID, pin checkbox.
- Pinned items: `#1A4CAF50` green tint background.

---

### Pinned Metrics in MainActivity

`MainActivity` maintains a secondary `CarApiReader` (`pinnedReader`) that reads only pinned signals (using `readSubset()`) at `250 ms` interval in the same `HandlerThread("Phase0LivePoll")`. The pinned metrics text is rendered as left-aligned `"%-20s %s\n"` formatted pairs.

The pinned metrics are refreshed by reloading `PinnedMetricsStore.load(this)` each poll cycle so pin/unpin changes made in `ApiBrowserActivity` are immediately reflected.

---

## Diagnostics Dashboard (3-Tab in MainActivity)

`MainActivity.setupTabsAndDiagnostics()` (line 659) sets up three tabs via `TabLayout`:
- Tab 0: HUD (main controls scroll view)
- Tab 1: DB Viewer (speedcam database, filter spinners by source and freshness)
- Tab 2: Harvester (service status, bridge fire timestamps, error display)

Source filter options: `"all"` / `"live"` / `"ynavi_native"` / `"import"` / `"seed"`.
Freshness filter: `"all"` / `"le7d"` / `"le30d"` / `"gt30d"`.

Diagnostics polling: 1-second interval via `diagPollHandler` / `diagPollRunnable` while activity is in foreground (`onStart`/`onStop` controlled).

**Service running detection** (line 833–835):
```kotlin
val running = am.getRunningServices(64)
    .any { it.service.className == "com.zeekr.phase0.carapp.CarAppHostService" }
```
Note: `ActivityManager.getRunningServices()` is deprecated for foreign apps but works for own-process services.

---

## SpeedCam DB / Post-MVP Architecture

### SpeedCameraDatabase (Room)

**File:** `SpeedCameraDatabase.kt`

```kotlin
@Database(entities = [SpeedCameraEntity::class], version = 2, exportSchema = false)
abstract class SpeedCameraDatabase : RoomDatabase() {
    abstract fun speedCameraDao(): SpeedCameraDao
}
```

DB file: `"speed_cameras.db"`. Migration 1→2 adds `headingAtSightingDeg REAL` column (nullable).

### SpeedCameraEntity

```kotlin
@Entity(tableName = "speed_cameras")
data class SpeedCameraEntity(
    @PrimaryKey val eventId: String,      // e.g. "m1_cam_01"
    val latitude: Double,
    val longitude: Double,
    val speedLimitKmh: Int,
    val eventType: String,                // e.g. "speed_camera"
    val allTags: String,                  // e.g. "SPEED_CONTROL"
    val firstSeenEpochMs: Long,
    val lastSeenEpochMs: Long,
    val seenCount: Int,
    val source: String,                   // "live" | "ynavi_native" | "import" | "seed"
    val headingAtSightingDeg: Float? = null   // C4 bearing filter, added in v2
)
```

### SpeedCameraDao key queries

- `getCamerasInBounds(minLat, maxLat, minLon, maxLon)` — bbox query, no index (scan acceptable for small table).
- `insertIfNew(camera)` — `OnConflictStrategy.IGNORE`, returns rowId or -1.
- `bumpSeen(eventId, ts)` — increments seenCount, updates lastSeenEpochMs.
- `bumpSeenWithHeading(eventId, ts, heading)` — same + `COALESCE(:heading, headingAtSightingDeg)` to preserve existing heading if new reading is null.
- `pruneStale(cutoffMs)` — delete rows where `lastSeenEpochMs < cutoffMs`.
- `getRecent(limit)` — `ORDER BY lastSeenEpochMs DESC`.

### SpeedCamProximityMonitor

**File:** `SpeedCamProximityMonitor.kt`

Runs on a single-thread executor. Bbox constants: `BBOX_LAT = 0.027` (~3 km), `BBOX_LON = 0.045` (~3 km at mid-Europe latitude). Hard cap `SEARCH_RADIUS_M = 2000.0` m after haversine. Max `MAX_CAMERAS = 5` returned.

C4 bearing-aware filter: suppresses cameras where `angularDistanceDeg(storedHeading, currentBearing) > BEARING_GATE_DEG (90.0)`. Fail-open: if stored heading is null OR current bearing is null, the camera passes through.

Geometry helpers (pure Kotlin, no Android deps, fully unit-testable):
- `haversineMeters(lat1, lon1, lat2, lon2): Double`
- `bearingDeg(lat1, lon1, lat2, lon2): Double` — initial bearing [0, 360)
- `angularDistanceDeg(a, b): Double` — smallest angle between two bearings [0, 180]
- `compassLabel(bearingDeg): String` — N/NE/E/SE/S/SW/W/NW
- `confidenceTier(cam, nowMs): Int` — 3 (seenCount≥5 AND ≤30d), 2 (seenCount≥2 OR ≤14d), 1 (else)

### SpeedCamBridgeStatus (observability singleton)

```kotlin
object SpeedCamBridgeStatus {
    @Volatile var lastBridgeFireEpochMs: Long = 0L
    @Volatile var totalEventsThisSession: Int = 0
    @Volatile var lastErrorMessage: String? = null
    @Volatile var lastErrorEpochMs: Long = 0L
    @Volatile var lastReliableBearingDeg: Float? = null  // null = no reliable GPS bearing yet
}
```

Bearing reliability threshold: `> 1.39 m/s` (≈5 km/h) from `CarAppHostService.BEARING_RELIABLE_MIN_MPS`.

### SpeedCamDataReceiver — Runtime Registration (CRITICAL)

The `SpeedCamDataReceiver` is registered at runtime inside `CarAppHostService.onCreate()` (line 511–523), **not** in the manifest. A manifest comment explains why:

> On Android 12+, implicit broadcasts from a normal app (YNavi) to another app's manifest receiver are blocked even when the receiving app has a foreground service running. A runtime receiver tied to the foreground service's lifecycle bypasses that restriction. Do not re-add this receiver here.

Registration:
```kotlin
val filter = IntentFilter(SpeedCamDataReceiver.ACTION_SPEEDCAM_DATA)
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
    registerReceiver(receiver, filter, RECEIVER_EXPORTED)
} else {
    registerReceiver(receiver, filter)
}
```

---

## Full Manifest Permissions Required

```xml
<!-- Boot receiver -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Foreground service (must declare type on Android 14+) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Overlay for PIP/virtual display -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<!-- YNavi force-stop (system-only, needs system app signing or adb grant) -->
<uses-permission android:name="android.permission.FORCE_STOP_PACKAGES" />

<!-- Doze whitelist via IDeviceIdleController -->
<uses-permission android:name="android.permission.DEVICE_POWER" />

<!-- Network state for proxy/watchdog diagnostics -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- GPS for speedcam proximity monitor -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- AOSP Car API -->
<uses-permission android:name="android.car.permission.CAR_PROPERTY" />
<uses-permission android:name="android.car.permission.CAR_EXTERIOR_LIGHTS" />
<uses-permission android:name="android.car.permission.CONTROL_CAR_EXTERIOR_LIGHTS" />
<uses-permission android:name="android.car.permission.TEMPLATE_RENDERER" />
<uses-permission android:name="androidx.car.app.NAVIGATION_TEMPLATES" />

<!-- Package visibility for YNavi -->
<queries>
    <package android:name="ru.yandex.yandexnavi" />
</queries>
```

---

## SharedPreferences Summary (All Files / Keys)

| SP file | Key | Type | Default | Use |
|---|---|---|---|---|
| `phase0_ui` | `auto_start_on_boot` | Boolean | `true` | BootNetworkWatchdog gate |
| `phase0_ui` | `viewport_mode` | String | null | Persists minimap viewport across restarts |
| `phase0_ui` | `blinker_running` | Boolean | false | Restore blinker on boot |
| `phase0_ui` | `minimap_running` | Boolean | false | Restore minimap on launch |
| `phase0_ui` | `locale_english` | Boolean | true | Cluster locale toggle state |
| `phase0_viewport` | `mode` | String | null | CarAppHostService viewport restore |
| `phase0_runtime` | `service_running` | Boolean | — | Observability |
| `phase0_runtime` | `minimap_active` | Boolean | — | Observability |
| `phase0_runtime` | `blinker_active` | Boolean | — | Observability |
| `pinned_metrics` | `ids` | Set&lt;String&gt; | emptySet | PinnedMetricsStore |

---

## PowerFlow Enum Values (for Diagnostics display)

```kotlin
0 → "NOT_READY"
604045574 → "ELEC"
604045585 → "PURE_ELE_AWD"
604045586 → "FRONT_ELE_DRIVE"
604045587 → "REAR_ELE_DRIVE"
604045588 → "STANDSTILL"
604045589 → "REGEN"
604045590 → "REGEN_FRONT"
604045591 → "REGEN_AWD"
```

---

## Efficiency Notes — No Stray Wake Locks

The architecture deliberately avoids:
- No `WakeLock` acquired anywhere in the boot/FGS path.
- No `AlarmManager` periodic wake-ups.
- No `WorkManager` (JobScheduler) boot tasks.

The foreground service provides the process keep-alive needed. The SpeedCam diagnostics poll in `MainActivity` uses `Handler.postDelayed()` — it only runs while the activity is visible. The `CarApiReader` poll in `ApiBrowserActivity` runs only between `onStart()`/`onStop()`. GPS updates use `requestLocationUpdates` with `GPS_MIN_TIME_MS=5000ms` and `GPS_MIN_DIST_M=10f` to minimize battery drain.


## Lift-ready artifacts

### BootNetworkWatchdog
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/boot/BootNetworkWatchdog.kt`
- **What:** BroadcastReceiver that receives BOOT_COMPLETED, reads auto_start_on_boot flag from SharedPreferences (phase0_ui), and calls startForegroundService with ACTION_BOOT_AUTOSTART.
- **Reuse:** Port directly to the new app's Kotlin module. Replace CarAppHostService reference with the new FGS class name. The PREFS_NAME/KEY_AUTO_START constants must match whatever the Flutter UI layer uses to toggle auto-start. Register in AndroidManifest with directBootAware=false and RECEIVE_BOOT_COMPLETED intent-filter.

### BootActions
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/boot/BootActions.kt`
- **What:** Kotlin object with static helpers: addDozeWhitelist (IDeviceIdleController reflection), pushClusterLocaleEnglish (AdaptAPI setFunctionValue 0x20318a00=1, 3 retries), startCarAppHost (startForegroundService), restartYNavi (ActivityManager.forceStopPackage). All thread-safe; callbacks posted to main thread.
- **Reuse:** Copy as-is. Update CarAppHostService reference. Requires ReflectionUtils (also in phase0). Keep retry count 3 / delay 1000ms for locale push — these values were tuned on-car. DEVICE_POWER permission required for Doze whitelist; FORCE_STOP_PACKAGES for restartYNavi (these may need system-app signing on production).

### CarApiCatalog + SignalDef + MetricValue
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiCatalog.kt`
- **What:** Complete static catalog of 51 vehicle signals across 6 groups (Battery, Motion, Charging, Body, Tires, AOSP). SignalDef carries label/hexId/source/group/unit. MetricValue is the runtime read result with changed-flag and pinned-flag.
- **Reuse:** Port to Dart as a pure data layer. SignalDef becomes an immutable Dart class or freezed union. CarApiCatalog.signals becomes a const list. The Kotlin side still needs to exist for the Android platform channel to read AdaptAPI; the Dart side uses the same hexId values and group/label metadata for display. The grouped lazy property is convenient for building section headers.

### CarApiReader
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiReader.kt`
- **What:** Kotlin class that connects to both AdaptAPI (getSensorLatestValue/getSensorEvent, getFunctionValue, getCustomizeFunctionValue) and AOSP CarPropertyManager (getIntProperty/getFloatProperty/getBooleanProperty). readAll/readSubset take catalog + previous-values map and return MetricValue list with changed-detection.
- **Reuse:** Use as the Android-side implementation of the Flutter platform channel for Diagnostics. Expose readSubset (for pinned metrics stream) and readAll (for full AP browser refresh) as MethodChannel/EventChannel calls. The 500ms poll interval from ApiBrowserActivity and 250ms from MainActivity are the validated on-car rates. Copy format() companion method for consistent value display on both sides.

### PinnedMetricsStore
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/PinnedMetricsStore.kt`
- **What:** SharedPreferences-backed store for a Set<Int> of pinned signal hexIds. Toggle is atomic (load-modify-save). Prefs file pinned_metrics, key ids, stored as Set<String> due to SharedPreferences API constraint.
- **Reuse:** Port to shared_preferences on the Flutter side, or keep the Kotlin implementation and expose load/toggle via MethodChannel. The Set<String> serialization quirk must be preserved if reusing the Android layer. In Flutter, store as List<int> in shared_preferences or hive.

### SpeedCameraEntity + SpeedCameraDao + SpeedCameraDatabase
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/speedcam/SpeedCameraDatabase.kt`
- **What:** Room DB v2 with speed_cameras table. Entity fields: eventId (PK), latitude, longitude, speedLimitKmh, eventType, allTags, firstSeenEpochMs, lastSeenEpochMs, seenCount, source, headingAtSightingDeg (nullable, v2). DAO provides bbox query, insertIfNew, bumpSeen/bumpSeenWithHeading (COALESCE on heading), pruneStale, getRecent.
- **Reuse:** This is the post-MVP speedcam store — port to the new app unchanged. MIGRATION_1_2 adds headingAtSightingDeg. The pruneStale(cutoffMs) call in CarAppHostService.onCreate() uses 90-day cutoff (STALE_DAYS_MS = 90 * 24 * 3_600_000). insertAllIfNew is used for seed data. bumpSeenWithHeading is the C4-aware upsert path.

### SpeedCamProximityMonitor
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/speedcam/SpeedCamProximityMonitor.kt`
- **What:** Single-executor proximity checker. Takes lat/lon/speedKmh/currentBearingDeg, does bbox DB query, applies C4 bearing filter (angularDistanceDeg > 90 deg = suppress), computes haversine+bearing to each result, returns up to 5 NearbyCamInfo sorted by distance within 2000m via onCamerasNearby/onNoCamerasNearby callbacks.
- **Reuse:** Port to new app Kotlin service layer unchanged. haversineMeters, bearingDeg, angularDistanceDeg, compassLabel, confidenceTier are pure math — can also be ported to Dart for UI-side calculations. Call shutdown() in Service.onDestroy(). Wire onCamerasNearby to HUD presentation and PIP overlay. BEARING_GATE_DEG=90 and BBOX_LAT/LON constants were tuned empirically.

### SpeedCamBridgeStatus
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/speedcam/SpeedCamBridgeStatus.kt`
- **What:** Process-wide observability singleton. Tracks lastBridgeFireEpochMs, totalEventsThisSession, lastErrorMessage/EpochMs, lastReliableBearingDeg. Pure @Volatile fields, no Android deps beyond Object.
- **Reuse:** Copy as-is into the new app's speedcam package. The Diagnostics dashboard reads lastBridgeFireEpochMs and totalEventsThisSession to surface harvester status. lastReliableBearingDeg flows from GPS listener to proximity monitor and to SpeedCamDataReceiver.upsertCamera().


## Concrete API surface

- android.intent.action.BOOT_COMPLETED
- com.zeekr.phase0.carapp.action.BOOT_AUTOSTART
- com.zeekr.phase0.carapp.action.START
- com.zeekr.phase0.carapp.action.STOP
- com.zeekr.phase0.carapp.action.SET_MINIMAP_VIEWPORT
- com.zeekr.phase0.carapp.action.APPLY_SETTINGS
- com.zeekr.phase0.carapp.action.SHOW_BLINKER
- com.zeekr.phase0.carapp.action.HIDE_BLINKER
- com.zeekr.phase0.carapp.action.TEST_SPEEDCAM
- com.zeekr.phase0.carapp.action.SPEEDCAM_STATUS_DUMP
- com.zeekr.phase0.carapp.action.SPEEDCAM_DB_CLEAR
- com.zeekr.phase0.carapp.action.RESTART_YNAVI_SILENT
- com.zeekr.phase0.carapp.action.SCREENSHOT
- extra_minimap_viewport_mode
- extra_startup_bind_delay_ms
- com.ecarx.xui.adaptapi.car.Car
- Car.create(context)
- Car.getSensorManager()
- Car.getICarFunction()
- ICarFunction.setFunctionValue(int functionId, int value)
- ICarFunction.getFunctionValue(int functionId)
- ICarFunction.getCustomizeFunctionValue(int functionId, int zone)
- ISensorManager.getSensorLatestValue(int sensorId)
- ISensorManager.getSensorEvent(int sensorId)
- android.car.Car
- android.car.Car.createCar(context, handler)
- CarPropertyManager.getIntProperty(int propId, int areaId)
- CarPropertyManager.getFloatProperty(int propId, int areaId)
- CarPropertyManager.getBooleanProperty(int propId, int areaId)
- android.os.IDeviceIdleController$Stub
- IDeviceIdleController.addPowerSaveWhitelistApp(String packageName)
- android.os.ServiceManager.getService(String name)
- ActivityManager.forceStopPackage(String packageName)
- LocationManager.requestLocationUpdates(provider, minTime=5000ms, minDist=10f, listener)
- LOCALE_FUNC_ID=0x20318a00
- LOCALE_ENGLISH=1
- SharedPreferences file: phase0_ui
- SharedPreferences key: auto_start_on_boot
- SharedPreferences key: viewport_mode
- SharedPreferences key: blinker_running
- SharedPreferences key: minimap_running
- SharedPreferences key: locale_english
- SharedPreferences file: phase0_viewport, key: mode
- SharedPreferences file: phase0_runtime, keys: service_running/minimap_active/blinker_active
- SharedPreferences file: pinned_metrics, key: ids
- android.car.permission.CAR_PROPERTY
- android.car.permission.CAR_EXTERIOR_LIGHTS
- android.car.permission.CONTROL_CAR_EXTERIOR_LIGHTS
- android.car.permission.TEMPLATE_RENDERER
- androidx.car.app.NAVIGATION_TEMPLATES
- android.permission.FOREGROUND_SERVICE_DATA_SYNC
- android.permission.FOREGROUND_SERVICE_LOCATION
- android.permission.DEVICE_POWER
- android.permission.FORCE_STOP_PACKAGES
- android.permission.RECEIVE_BOOT_COMPLETED
- android.permission.ACCESS_BACKGROUND_LOCATION
- CarAppHostService notification channel: phase0_carapp_host, NOTIF_ID=1001
- Room DB: speed_cameras.db, table: speed_cameras, v2
- SpeedCameraDao.getCamerasInBounds
- SpeedCameraDao.bumpSeenWithHeading
- SpeedCameraDao.pruneStale
- SpeedCamProximityMonitor.BBOX_LAT=0.027, BBOX_LON=0.045, SEARCH_RADIUS_M=2000, MAX_CAMERAS=5
- SpeedCamProximityMonitor.BEARING_GATE_DEG=90.0
- CarAppHostService.BEARING_RELIABLE_MIN_MPS=1.39f
- CarAppHostService.STALE_DAYS_MS=90*24*3600000
- CarAppHostService.GPS_MIN_TIME_MS=5000, GPS_MIN_DIST_M=10f
- CarAppHostService.HUD_DISPLAY_ID=2
- CarAppHostService.RECONNECT_DELAY_MS=5000
- CarAppHostService.REBIND_DELAY_MS=2000
- ApiBrowserActivity.POLL_INTERVAL_MS=500
- MainActivity.LIVE_POLL_INTERVAL_MS=250
- MainActivity.UI_SCALE=1.75f

## Risks

- FORCE_STOP_PACKAGES and DEVICE_POWER permissions are system-level on AOSP hardened builds. On a Zeekr DHU that allows these (confirmed working in phase0), the new app must be signed with the same platform/system key or granted via adb/policy. Verify before assuming these work in the new app.
- AdaptAPI (com.ecarx.xui.adaptapi.car.Car) is accessed entirely via reflection (ReflectionUtils). The class path, method names (getSensorManager, getICarFunction, getSensorLatestValue, getFunctionValue, setFunctionValue, getCustomizeFunctionValue), and return types are not validated at compile time. Any firmware update on the Zeekr DHU that renames or restructures these methods will silently break all AdaptAPI reads. The port should implement a version probe at connect() time.
- Float.MIN_VALUE is used as a sentinel 'no data' value by the AdaptAPI SensorManager. This is an undocumented convention discovered empirically in phase0. If the firmware changes this sentinel (e.g., to NaN or 0), all sensor reads will return null silently. The readSensorFloat guard (CarApiReader lines 83-85) must be preserved exactly.
- SpeedCamDataReceiver must be registered at runtime (not in manifest) for Android 12+ implicit broadcast delivery from YNavi (a third-party app). A manifest-declared receiver would be blocked by the Background Execution Limits even with a foreground service running. This is explicitly documented in the manifest comment at line 101-108. Do NOT move this to manifest registration in the new app.
- SYSTEM_ALERT_WINDOW is required for the PIP speed-cam overlay and for the virtual HUD display fallback. On Android 13+, apps targeting API 33+ cannot declare this in manifest without user action via Settings.ACTION_MANAGE_OVERLAY_PERMISSION. The new app must prompt the user and check Settings.canDrawOverlays() before attempting overlay operations.
- pushClusterLocaleEnglish reads back 255 (undefined) even on successful write — the code correctly ignores the read-back result. Any future attempt to verify locale by reading the same function ID (0x20318a00) will get 255 and must not be treated as failure.
- The 3-tab Diagnostics UI in MainActivity uses a simple visibility-swap pattern (no ViewPager2/Fragment) which is fine for static tabs. Porting to Flutter pages/tabs is straightforward, but the 1-second diagPoll loop must be lifecycle-bound (only active when the diagnostics screen is visible) to avoid unnecessary background DB reads.
- CarAppHostService returns START_STICKY. If the OS kills the service and restarts it, onStartCommand receives a null intent. The service's when() dispatch does nothing for null intent but falls through to ensureHudPresentation() + bindToNavigationCarApp() in the else branch. The new app must replicate this fallback behavior.
- The YNavi reconnect loop (RECONNECT_DELAY_MS=5000ms) schedules rebind on onServiceDisconnected and onBindingDied. If minimapActive is false when the service is killed and restarted (START_STICKY restart), no rebind is attempted. The persisted phase0_runtime/minimap_active flag is not consulted on restart because the null-intent path only calls ensureHudPresentation() without setting minimapActive=true. This is a known limitation — the new app should read the persisted runtime flag in the null-intent path.
- DB v2 migration adds headingAtSightingDeg as REAL (nullable). Any test seeding SpeedCameraEntity without the headingAtSightingDeg param must use the default (null) to avoid compile errors after migration. The bearing-aware filter is fail-open for null heading rows.
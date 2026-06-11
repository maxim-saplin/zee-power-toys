# Knowledge: car-signals-adaptapi

## AdaptAPI Live Car Signals — Phase0 Ground Truth

### Architecture Overview

The Zeekr 001 (Aptiv DHU, Android 12) runs Android as a VM inside the Aptiv hypervisor. CAN bus data is bridged to Android exclusively through the **Zeekr AdaptAPI (Ecarx)**. Standard AAOS CarProperty/OBD2 are registered but never fed with real data — all live signal work must go through AdaptAPI.

```
CAN Bus → Aptiv VHAL (QNX/Linux) → IPC bridge → AdaptAPI (Android VM)
                                                    ├── ISensor (polling + callbacks)
                                                    └── ICarFunction (polling + callbacks)
```

The deprecated launcher proxy path (Track B: `HudProxyClient` → `ecarx.launcher3/HudProxyService`) is archived in `DEPRECATED_PROXY_API.md` and must NOT be used in new code.

---

### Connecting to AdaptAPI

**Entry point** (`CarApiReader.kt:18-29`, `BcmFunctionProbe.kt:34-40`, `DirectHudPresentationManager.kt:197-206`):

```kotlin
val carClass = ReflectionUtils.classForName("com.ecarx.xui.adaptapi.car.Car")
val iCar     = ReflectionUtils.callStatic(carClass, "create", context)
val sensorMgr    = ReflectionUtils.callInstance(iCar, "getSensorManager")   // ISensor
val functionMgr  = ReflectionUtils.callInstance(iCar, "getICarFunction")    // ICarFunction
```

All calls go through `ReflectionUtils` (`ReflectionUtils.kt`) because the AdaptAPI SDK is a system-framework class not available as a compile-time dependency; it is accessed entirely via reflection against the live system classpath. No `compileOnly` jar is needed — the classes exist on the device's boot classpath.

**Teardown** (`CarApiReader.kt:44-51`):
```kotlin
ReflectionUtils.callInstance(iCar, "disconnect")
```

One `disconnect()` call on the `iCar` instance is sufficient. Do NOT re-register a listener in the same process after `disconnect()` without creating a fresh `Car.create()` instance — re-registration in the same process fails silently (`CAR_API.md` line 84).

---

### Read Method Summary

| Method | Interface | Return | Use |
|--------|-----------|--------|-----|
| `getSensorLatestValue(id: Int)` | ISensor | Float | Continuous sensors (speed, battery %, temp, pedals) |
| `getSensorEvent(id: Int)` | ISensor | Int | Enum-type sensors (gear, battery state) |
| `getFunctionValue(id: Int)` | ICarFunction | Int | Boolean/enum functions (blinkers, power flow, plug state) |
| `getCustomizeFunctionValue(id: Int, zone: Int)` | ICarFunction | Float | Float functions (charging V/A/kW) |

For `getCustomizeFunctionValue`, use `zone = 0x80000000` (ZONE_GLOBAL) for charging signals (`PowerMagnitudeProbe.kt:65`, `CAR_API.md:152-158`).

---

### Signal-by-Signal Reference

#### Speed
- **ID**: `0x00100100`
- **Method**: `ISensor.getSensorLatestValue(0x00100100)`
- **Returns**: Float in **m/s** (multiply by 3.6 for km/h)
- **Update**: ~4 Hz polling; also fires `onSensorValueChanged` callback
- **Verified**: 23.6 m/s = 85 km/h, 27.8 m/s = 100 km/h
- **Source**: `CAR_API.md:96`, `EnergyProbe.kt:179`, `CarApiCatalog.kt:49`

#### Blinker Left
- **ID**: `0x21051100`
- **Method**: `ICarFunction.getFunctionValue(0x21051100)`
- **Returns**: Int, `0` = off, `1` = on
- **Update**: Callback via `onFunctionValueChanged` when stalk toggled
- **Source**: `BcmFunctionProbe.kt:23`, `CAR_API.md:139`

#### Blinker Right
- **ID**: `0x21051200`
- **Method**: `ICarFunction.getFunctionValue(0x21051200)`
- **Returns**: Int, `0` = off, `1` = on
- **Update**: Callback via `onFunctionValueChanged`
- **Source**: `BcmFunctionProbe.kt:24`, `CAR_API.md:140`

#### Blinker Hazard (DEAD)
- **ID**: `0x21050F00`
- **Returns**: Always 255 (sentinel = no data). Do NOT use.
- **Hazard detection workaround**: check `left == 1 && right == 1` (`DirectHudPresentationManager.kt:192-193`)

#### Charging State / Battery State
- **ID**: `0x00201500`
- **Method**: `ISensor.getSensorEvent(0x00201500)`
- **Returns**: Int enum (charging/discharging/idle)
- **Update**: On-change callback via `onSensorEventChanged`
- **Source**: `CarApiCatalog.kt:37`, `EnergyProbe.kt:169`

#### Battery Level (Raw)
- **ID**: `0x00100A00`
- **Method**: `ISensor.getSensorLatestValue(0x00100A00)`
- **Returns**: Float, % (0–100)
- **Update**: Slow (~16 s period or less)
- **Source**: `CarApiCatalog.kt:34`, `EnergyProbe.kt:166`

#### Battery SoC (Filtered/Virtual)
- **ID**: `0x00404000`
- **Method**: `ISensor.getSensorLatestValue(0x00404000)`
- **Returns**: Float, % (0–100), software-filtered value
- **Source**: `CarApiCatalog.kt:33`, `EnergyProbe.kt:167`

#### Battery Temperature
- **ID**: `0x00102A00`
- **Method**: `ISensor.getSensorLatestValue(0x00102A00)`
- **Returns**: Float, degrees Celsius, verified range 15–40°C
- **Update**: Slow/static
- **Source**: `CarApiCatalog.kt:35`, `EnergyProbe.kt:169`

#### Charging Voltage (LIVE — only during active charge)
- **ID**: `0x24140100`
- **Method**: `ICarFunction.getCustomizeFunctionValue(0x24140100, 0x80000000)`
- **Returns**: Float, Volts; verified range 736–763 V
- **Update**: ~1 Hz via `onCustomizeFunctionValueChanged` callback
- **Sentinel when not charging**: 0.0 or `Float.MIN_VALUE`
- **Source**: `CAR_API.md:152`, `EnergyProbe.kt:130`, `PowerMagnitudeProbe.kt:598`

#### Charging Current (LIVE — only during active charge)
- **ID**: `0x24140200`
- **Method**: `ICarFunction.getCustomizeFunctionValue(0x24140200, 0x80000000)`
- **Returns**: Float, Amperes; verified range 27–80 A
- **Update**: ~2 Hz via `onCustomizeFunctionValueChanged`
- **Source**: `CAR_API.md:152`, `EnergyProbe.kt:131`

#### Charging Power (LIVE — only during active charge)
- **ID**: `0x2420C000` (canonical live ID; `0x241E0500` is dead — always 255)
- **Method**: `ICarFunction.getCustomizeFunctionValue(0x2420C000, 0x80000000)`
- **Returns**: Float, kW; verified range 20–61 kW
- **Update**: ~2 Hz via `onCustomizeFunctionValueChanged`
- **Source**: `CAR_API.md:153`, `EnergyProbe.kt:64-65`, `PowerMagnitudeProbe.kt:599`

#### Power Flow State (drive/regen/standstill)
- **ID**: `0x24010100`
- **Method**: `ICarFunction.getFunctionValue(0x24010100)`
- **Returns**: Int enum; verified values:
  - `0` = NOT_READY
  - `604045574` (+6) = ELEC
  - `604045585` (+17) = PURE_ELE_AWD
  - `604045586` (+18) = FRONT_ELE_DRIVE
  - `604045587` (+19) = REAR_ELE_DRIVE
  - `604045588` (+20) = STANDSTILL
  - `604045589` (+21) = REGEN
  - `604045590` (+22) = REGEN_FRONT
  - `604045591` (+23) = REGEN_AWD
- **Update**: ~2 Hz via `onFunctionValueChanged` watcher callbacks during driving
- **Source**: `CAR_API.md:114-128`, `EnergyProbe.kt:147`

---

### Callback / Event-Driven vs Poll

| Signal | Mechanism | Interface | Callback Method |
|--------|-----------|-----------|-----------------|
| Speed (`0x00100100`) | Both | ISensor | `onSensorValueChanged(id: Int, value: Float)` |
| Gear (`0x00200500`) | Event/callback | ISensor | `onSensorEventChanged(id: Int, event: Int)` |
| Battery State (`0x00201500`) | Event/callback | ISensor | `onSensorEventChanged(id: Int, event: Int)` |
| Battery SoC/Level/Temp | Poll + callback | ISensor | `onSensorValueChanged(id: Int, value: Float)` |
| Blinkers (`0x21051100/200`) | Callback preferred | ICarFunction | `onFunctionValueChanged(id: Int, zone: Int, value: Int)` |
| Power Flow (`0x24010100`) | Callback, ~2 Hz | ICarFunction | `onFunctionValueChanged(id: Int, zone: Int, value: Int)` |
| Charging V/A/kW | Callback, ~1-2 Hz | ICarFunction | `onCustomizeFunctionValueChanged(id: Int, zone: Int, value: Float)` |

---

### Registering Listeners

#### ISensor listener registration (`PowerMagnitudeProbe.kt:219-229`, `CAR_API.md:81`)

Listener interface: `com.ecarx.xui.adaptapi.car.sensor.ISensor$ISensorListener`
(alternative candidate tried: `com.zeekrlife.adaptapi.car.impl.ISensorImpl$ISensorListener`)

```kotlin
// Try 3-arg form first (with rate), fall back to 2-arg
val r = ReflectionUtils.callInstanceResult(sensorMgr, "registerListener", listener, sensorId, SENSOR_RATE_NORMAL)
// if that fails:
ReflectionUtils.callInstanceResult(sensorMgr, "registerListener", listener, sensorId)

// Teardown — ONE call unregisters from all IDs
ReflectionUtils.callInstanceResult(sensorMgr, "unregisterListener", listener)
```

Listener methods:
- `onSensorValueChanged(id: Int, value: Float)`
- `onSensorEventChanged(id: Int, event: Int)`
- `onSensorSupportChanged(id: Int, status: FunctionStatus)`

#### ICarFunction watcher registration (`BcmFunctionProbe.kt:140-177`, `CAR_API.md:82`)

Watcher interface: `com.ecarx.xui.adaptapi.car.base.ICarFunction$IFunctionValueWatcher`

```kotlin
// Pass an IntArray of all IDs you want to watch in one call
val ids = intArrayOf(0x21051100, 0x21051200, 0x24010100, 0x24140100, 0x24140200, 0x2420C000)
val r = ReflectionUtils.callInstanceResult(carFunction, "registerFunctionValueWatcher", ids, watcher)

// Teardown
ReflectionUtils.callInstanceResult(carFunction, "unregisterFunctionValueWatcher", ids, watcher)
```

Watcher methods:
- `onFunctionValueChanged(id: Int, zone: Int, value: Int)` — integer functions
- `onCustomizeFunctionValueChanged(id: Int, zone: Int, value: Float)` — float functions

---

### Sentinel Value Filtering

Always filter these before using raw values (`CAR_API.md:254-263`):

| Type | Sentinel | Meaning |
|------|----------|---------|
| Int | `255` | No data / not available |
| Int | `-1` | Error |
| Int | value ≈ ID itself | ID echo (e.g. 0x24010100 → 604045568) |
| Float | `Float.MIN_VALUE` (1.401E-45) | No data |
| Float | `0.0` | Sentinel for `getCustomizeFunctionValue` when signal inactive |
| Float | `NaN`, `Infinity` | Error |

From `CarApiReader.kt:82-83`:
```kotlin
if (value != null && value == Float.MIN_VALUE) return null
```

From `PowerMagnitudeProbe.kt:552-553`:
```kotlin
fun nonSentinelInt(v: Int?) = v != null && v != 255 && v != -1 && v != 0
fun nonSentinelFloat(v: Float?) = v != null && v != Float.MIN_VALUE && v != 0f && !v.isNaN() && !v.isInfinite()
```

---

### Dead / Non-functional Signals (Do Not Port)

From `CAR_API.md:221-232`:

| Signal | ID | Issue |
|--------|-----|-------|
| Discharge Power Actual | `0x00103600` | Always 255, zero callbacks |
| Discharge Limit | `0x00103500` | Always 255, zero callbacks |
| Charging Power (legacy) | `0x241E0500` | Always 255 / Float.MIN_VALUE |
| Regen Bar A | `0x24215C00` | Always 255 |
| Regen Bar B | `0x241E5000` | Always 255 |
| Charge/Discharge Status | `0x241D2500` | Always 255 |
| Hybrid SoC | `0x24010500` | Always 255 |
| Power Flow HEV | `0x24010200` | Always 255 |
| Blinker Hazard | `0x21050F00` | Always 255 |

**All AAOS CarProperty IDs** (`CarApiCatalog.kt:97-108`) return frozen/stale values. `PERF_VEHICLE_SPEED (0x11600207) = 0.0`, `EV_BATTERY_LEVEL (0x11600309) = 150000.0`. These are confirmed non-functional.

---

### SignalStore (harness-side cache)

`SignalStore.kt` is a simple in-memory + SharedPreferences store for blinker state only. It is NOT a general-purpose AdaptAPI cache:

```kotlin
data class SignalState(val left: Boolean, val right: Boolean, val hazard: Boolean)
object SignalStore {
    fun get(): SignalState         // in-memory snapshot
    fun get(context: Context): SignalState  // persisted snapshot (SharedPrefs "hud_signal_store")
    fun applyCommand(command: String?): SignalState  // "LEFT"/"RIGHT"/"HAZARD"/"OFF"
    fun isSimulated(): Boolean
}
```

SharedPrefs keys: `KEY_LEFT = "left"`, `KEY_RIGHT = "right"`, `KEY_HAZARD = "hazard"`, `KEY_SIM_ENABLED = "sim_enabled"`.

The new Flutter+Kotlin CarSignals service should model ALL signals (not just blinker) in a Kotlin-side state holder that feeds the Flutter layer via a method channel or event channel, using the patterns above.

---

### Gradle / SDK Dependencies

From `app/build.gradle.kts` (lines 72-79): The AdaptAPI is NOT declared as a Gradle dependency. It is a **system framework class** present on the device's boot classpath. The phase0 app only declares:

```kotlin
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    // ...standard AndroidX only...
}
```

The AdaptAPI classes (`com.ecarx.xui.adaptapi.car.*`) are accessed entirely through reflection via `ReflectionUtils`. For the new Flutter+Kotlin host, the same approach applies: no SDK jar needed, all calls via reflection or (if a stub jar is available) a `compileOnly fileTree(dir: "libs")` entry pointing to an AdaptAPI stub.

The signing key matters: `tools/zeekr/androiddebugkey.jks` is the Zeekr/AOSP debug key required to install and have system-level access on the DHU. The new app's `build.gradle.kts` should mirror the `signingConfigs` block from `app/build.gradle.kts:26-35`.

---

### Blinker Polling Pattern (Production-Verified)

From `DirectHudPresentationManager.kt:166-194` — the production blinker display loop:

- Poll interval: **50 ms** when signals active, **1000 ms** backoff when API fails
- Blink visual cycle: **450 ms** toggle period
- Hazard detection: `left == 1 && right == 1` (not the dead hazard ID)
- API init is lazy (`ensureFunctionManager()`) — reconnects on next poll cycle if `disconnect()` was called

---

### Minimum Viable HUD Signal Set

```kotlin
// Sensor IDs (use ISensor.getSensorLatestValue or getSensorEvent)
val SPEED         = 0x00100100  // Float, m/s, ×3.6 → km/h
val GEAR          = 0x00200500  // Int enum (0=P,1=R,2=N,3=D) via getSensorEvent
val BATTERY_SOC   = 0x00404000  // Float, %
val BATTERY_LEVEL = 0x00100A00  // Float, %
val BATTERY_TEMP  = 0x00102A00  // Float, °C
val BATTERY_STATE = 0x00201500  // Int enum via getSensorEvent

// Function IDs (use ICarFunction.getFunctionValue)
val BLINKER_LEFT  = 0x21051100  // Int 0/1
val BLINKER_RIGHT = 0x21051200  // Int 0/1
val POWER_FLOW    = 0x24010100  // Int enum (drive/regen states)

// Charging float IDs (use ICarFunction.getCustomizeFunctionValue(id, 0x80000000))
val CHARGE_VOLTAGE = 0x24140100  // Float, V (live only during charging)
val CHARGE_CURRENT = 0x24140200  // Float, A (live only during charging)
val CHARGE_POWER   = 0x2420C000  // Float, kW (live only during charging)

// Additional charging info (use ICarFunction.getFunctionValue)
val PLUG_STATE     = 0x24130200  // Int 12-state enum
val CHARGE_SOC     = 0x24100200  // Int, %
val CHARGE_EST     = 0x24120300  // Int, minutes
```

---

### Alternative Zeekr SDK Path (Exploratory)

`BcmFunctionProbe.kt:77-133` also probes `com.zeekr.sdk.car.impl.CarAPI` (Zeekr's own SDK layer):

```kotlin
val carApiClass = ReflectionUtils.classForName("com.zeekr.sdk.car.impl.CarAPI")
val carApi = ReflectionUtils.callStatic(carApiClass, "get")
// init with ApiReadyCallback from "com.zeekr.sdk.base.ApiReadyCallback"
val carFunction = ReflectionUtils.callInstance(carApi, "getCarFunctionApi")
// getFunctionValue(id, 0) — note extra zone=0 arg
val left = ReflectionUtils.callInstance(carFunction, "getFunctionValue", BCM_LEFT, 0)
// Watcher: "com.zeekr.sdk.vehicle.base.observer.IFunctionValueObserver"
// registerFunctionValueWatcher(List<Int>, observer)
```

This path was probed but there is no documented evidence it returns better data than the primary Ecarx path. The primary Ecarx path (`com.ecarx.xui.adaptapi.car.Car`) is confirmed working and should be the sole path in the new service.


## Lift-ready artifacts

### ReflectionUtils
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/ReflectionUtils.kt`
- **What:** Reflection helper that locates methods by name+arity, handles primitive/wrapper compatibility, and wraps results in ReflectionCallResult. Used for all AdaptAPI calls since the SDK is not available at compile time.
- **Reuse:** Copy verbatim into the new Kotlin module (e.g., com.zeepowertoys.native.ReflectionUtils). All CarSignals service calls route through this.

### CarApiReader
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiReader.kt`
- **What:** Stateful connection holder for AdaptAPI: holds sensorMgr + functionMgr instances, exposes readSensorFloat / readFunctionInt / readFunctionFloat methods with sentinel filtering.
- **Reuse:** Port the connect()/disconnect() lifecycle and the three private read methods directly. Replace the reflection shim with direct calls if a stub jar is available, otherwise keep as-is.

### CarApiCatalog
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/apibrowser/CarApiCatalog.kt`
- **What:** Master catalogue of all signal IDs, their ApiSource (ADAPT_SENSOR / ADAPT_FUNCTION / CAR_PROPERTY), group, and unit. Single source of truth for what ID to read with which method.
- **Reuse:** Port the constant definitions (hexId, source, unit) into the new CarSignals service constants file. Use as the authoritative ID→method mapping table.

### BcmFunctionProbe.registerAdaptCallback
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/probes/BcmFunctionProbe.kt`
- **What:** Working example of IFunctionValueWatcher registration via registerFunctionValueWatcher(IntArray, watcher). Covers both the proxy and direct Ecarx paths; the direct (runAdaptProbe) path is what to port.
- **Reuse:** Copy registerAdaptCallback() pattern into the new CarSignalsService. The watcher interface class name 'com.ecarx.xui.adaptapi.car.base.ICarFunction$IFunctionValueWatcher' and the registerFunctionValueWatcher(intArrayOf(...), watcher) call signature are verified working.

### BlinkerPresentation polling loop
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/DirectHudPresentationManager.kt`
- **What:** Production-verified blinker polling loop: 50 ms active poll, 1 s backoff on API failure, lazy API init, hazard = left&&right, reconnect on failure. Used in the live blinker display.
- **Reuse:** The readDirectSignals() / ensureFunctionManager() / disconnectApi() trio is the exact pattern for the new CarSignals native service blinker reader. Port to Kotlin coroutine loop with equivalent delays.

### PowerMagnitudeProbe sentinel filters
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/probes/PowerMagnitudeProbe.kt`
- **What:** nonSentinelInt() and nonSentinelFloat() helpers that correctly filter all known sentinel values (255, -1, 0, Float.MIN_VALUE, NaN, Infinity).
- **Reuse:** Copy both helpers into the CarSignals service utility class. Every raw AdaptAPI value must pass through these before being emitted to Flutter.

### SignalStore
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/harness/SignalStore.kt`
- **What:** In-memory + SharedPrefs cache for blinker state, with simulation toggle. Used by the production blinker display to support ADB-injected test signals.
- **Reuse:** Port the SimulateEnabled + applyCommand pattern for the new app's ADB simulation mode. Extend SignalState to cover all HUD signals (speed, SoC, temp, charging) rather than just blinkers.


## Concrete API surface

- com.ecarx.xui.adaptapi.car.Car
- Car.create(context: Context): ICar
- ICar.getSensorManager(): ISensor
- ICar.getICarFunction(): ICarFunction
- ICar.disconnect()
- ISensor.getSensorLatestValue(sensorId: Int): Float
- ISensor.getSensorEvent(sensorId: Int): Int
- ISensor.registerListener(listener, sensorId: Int)
- ISensor.registerListener(listener, sensorId: Int, rate: Int)
- ISensor.unregisterListener(listener)
- com.ecarx.xui.adaptapi.car.sensor.ISensor$ISensorListener
- ISensorListener.onSensorValueChanged(id: Int, value: Float)
- ISensorListener.onSensorEventChanged(id: Int, event: Int)
- ISensorListener.onSensorSupportChanged(id: Int, status: FunctionStatus)
- ICarFunction.getFunctionValue(id: Int): Int
- ICarFunction.getCustomizeFunctionValue(id: Int, zone: Int): Float
- ICarFunction.setFunctionValue(id: Int, value: Int)
- ICarFunction.registerFunctionValueWatcher(ids: IntArray, watcher)
- ICarFunction.unregisterFunctionValueWatcher(ids: IntArray, watcher)
- com.ecarx.xui.adaptapi.car.base.ICarFunction$IFunctionValueWatcher
- IFunctionValueWatcher.onFunctionValueChanged(id: Int, zone: Int, value: Int)
- IFunctionValueWatcher.onCustomizeFunctionValueChanged(id: Int, zone: Int, value: Float)
- SENSOR_ID_SPEED=0x00100100
- SENSOR_ID_GEAR=0x00200500
- SENSOR_ID_BATTERY_SOC=0x00404000
- SENSOR_ID_BATTERY_LEVEL=0x00100A00
- SENSOR_ID_BATTERY_TEMP=0x00102A00
- SENSOR_ID_BATTERY_STATE=0x00201500
- SENSOR_ID_BRAKE_PEDAL=0x00101300
- SENSOR_ID_ACCEL_PEDAL=0x00101400
- FUNC_ID_BLINKER_LEFT=0x21051100
- FUNC_ID_BLINKER_RIGHT=0x21051200
- FUNC_ID_BLINKER_HAZARD=0x21050F00 (DEAD - always 255)
- FUNC_ID_POWER_FLOW=0x24010100
- FUNC_ID_CHARGE_VOLTAGE=0x24140100
- FUNC_ID_CHARGE_CURRENT=0x24140200
- FUNC_ID_CHARGE_POWER=0x2420C000
- FUNC_ID_PLUG_STATE=0x24130200
- FUNC_ID_CHARGE_SOC=0x24100200
- FUNC_ID_CHARGE_EST_TIME=0x24120300
- FUNC_ID_DRIVE_MODE=0x22010100
- ZONE_GLOBAL=0x80000000
- com.zeekr.sdk.car.impl.CarAPI (secondary/exploratory path)
- com.zeekr.sdk.vehicle.base.observer.IFunctionValueObserver (secondary/exploratory path)

## Risks

- AdaptAPI is accessed entirely via reflection — class names could change between firmware builds (CAR_API.md documents build 2025-12-10 / firmware 30_0-30_8). New firmware OTA may break class paths.
- Re-registering a listener in the same process after disconnect() fails silently. The new service must create a fresh Car.create() instance if reconnecting — never reuse the old ISensor/ICarFunction handle after disconnect.
- Blinker hazard ID 0x21050F00 always returns 255 on this firmware. Any code that reads it as a real signal will behave incorrectly. Hazard must be inferred from left==1 && right==1.
- Charging signals (voltage 0x24140100, current 0x24140200, power 0x2420C000) return 0 or Float.MIN_VALUE when not charging — the sentinel filter must be applied before emitting to Flutter, or the UI will display stale zero values.
- Dead power signals: 0x241E0500 (charging power legacy), 0x00103600 (discharge power actual), 0x00103500 (discharge limit), 0x24215C00 (regen bar A), 0x241E5000 (regen bar B) always return 255. Porting these would produce silent bad data.
- AAOS CarProperty interface is registered but never populated by the Aptiv VHAL — PERF_VEHICLE_SPEED=0, EV_BATTERY_LEVEL=150000 (stale boot value). Must not use CarPropertyManager for any live signal.
- No compile-time stub for AdaptAPI — compilation on a non-car machine requires either reflection-only calls (current approach) or a stub jar. Missing stub will cause IDE false-positive errors but not runtime failures.
- The signing key (tools/zeekr/androiddebugkey.jks) is required for the app to work on the car's Android partition. A standard Google debug key will result in permission denials or failed installs.
- Power Flow state enum values are large raw integers (604045574–604045591) not sequential. UI code must compare to the exact documented constants, not do range arithmetic.
- Speed is in m/s natively — multiply by 3.6 for km/h. Getting this wrong produces a value ~3.6x too low in the HUD.
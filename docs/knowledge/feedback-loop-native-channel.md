# Knowledge: feedback-loop-native-channel

# phase0 Native Debug/Inject Harness — Findings for ADR 0004 Upgrade

## 1. SIMULATE Broadcast — Signal Injection API

### Intent contract

| Key | Type | Values |
|-----|------|--------|
| Action | string | `com.zeekr.phase0.SIMULATE` |
| `value` (extra) | String | `SIM_ON`, `SIM_OFF`, `LEFT`, `RIGHT`, `HAZARD`, `OFF` |

Source: `SimulateReceiver.kt:33` — `const val ACTION_SIMULATE = "com.zeekr.phase0.SIMULATE"` and `:14` — `val value = intent.getStringExtra(EXTRA_VALUE)` where `EXTRA_VALUE = "value"`.

Note: HUD.md line 156 also shows `--es command LEFT` — an older extra name `command`, but the live code at `SimulateReceiver.kt:14` reads `EXTRA_VALUE = "value"`. The docs example is probably stale; `value` is authoritative.

### Manifest registration

```xml
<receiver android:name="com.zeekr.phase0.harness.SimulateReceiver" android:exported="true">
    <intent-filter>
        <action android:name="com.zeekr.phase0.SIMULATE" />
    </intent-filter>
</receiver>
```

`AndroidManifest.xml:86-91`

### ADB CLI form (phase0 practice)

```bash
# Enable sim mode
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value SIM_ON

# Set blinker state
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value LEFT
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value RIGHT
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value HAZARD
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value OFF

# Disable sim mode
adb shell am broadcast -a com.zeekr.phase0.SIMULATE --es value SIM_OFF
```

### What SimulateReceiver does (SimulateReceiver.kt:10-28)

1. Checks `intent.action == ACTION_SIMULATE`; bails if not.
2. Reads `value` extra.
3. `SIM_ON` / `SIM_OFF` → `SignalStore.setSimulatedEnabled(context, enabled)` — persists to SharedPrefs key `sim_enabled` in prefs file `hud_signal_store`.
4. Any other value → `SignalStore.applyCommand(context, value)` which normalises to uppercase and writes LEFT/RIGHT/HAZARD/OFF state into prefs keys `left`, `right`, `hazard` in same `hud_signal_store` prefs.

**No speed or charge injection exists in phase0.** The SIMULATE channel only covers turn signals. Speed and charge must be added in the new app.

### SignalStore persistence (SignalStore.kt:19-91)

- In-memory `@Volatile` singleton + SharedPrefs persistence under `hud_signal_store`.
- `get()` returns in-memory state; `get(context)` returns prefs-backed state.
- `applyCommand(context, command)` writes prefs synchronously (`.apply()` = async commit).
- `BlinkerOverlayView` polls `SignalStore.get(context)` from a `HandlerThread` loop — it reads the simulated state directly from the store, bypassing any native API when `isSimulated()` is true.

---

## 2. PROBE Broadcast — Async Probe-And-Dump API

### Intent contract (ProbeRunner.kt:267-283)

| Extra key | Type | Default | Meaning |
|-----------|------|---------|---------|
| `probes` | String | `"all"` | Which probe group: `signals`, `display`, `system`, `energy`, `carapp`, `locale`, `setting_zeekr`, `remote_energy`, `vehicle_condition_energy`, `setting_trip_energy`, `power_magnitude`, `all` |
| `source` | String | null | Sub-source: `carlight`, `bcm`, `turnsignal`/`car_property`, `sweep`, `sensor`, `function`, etc. |
| `output` | String | null | `"json"` to write `last.json` |
| `track` | String | `"a"` | `"a"` (direct AdaptAPI) or `"b"` (via proxy binder) |
| `display` | String | null | `direct`, `multidisplay`, `all` |
| `display_id` | Int | -1 | specific display id |
| `system_dumps` | String | null | `"true"` to include dumpsys |
| `sweep_ms` | Long | 12000 | sweep window ms |
| `sweep_interval_ms` | Long | 200 | poll interval ms |
| `signal_ids` | String | null | comma/space/semicolon-separated hex or decimal IDs |
| `locale_mode` | String | `"read"` | |
| `locale_lang` | Int | 1 | |

### Manifest registration

```xml
<receiver android:name=".Phase0ProbeReceiver" android:exported="true">
    <intent-filter>
        <action android:name="com.zeekr.phase0.PROBE" />
    </intent-filter>
</receiver>
<service android:name=".Phase0ProbeJobIntentService"
         android:exported="false"
         android:permission="android.permission.BIND_JOB_SERVICE" />
```

`AndroidManifest.xml:77-83,111-113`

### Async execution chain

```
adb shell am broadcast -a com.zeekr.phase0.PROBE --es probes signals --es output json
    │
    ▼
Phase0ProbeReceiver.onReceive()         [Phase0ProbeReceiver.kt:9-16]
    → Phase0ProbeJobIntentService.enqueueWork(context, intent)
    │
    ▼
Phase0ProbeJobIntentService.onHandleWork()   [Phase0ProbeJobIntentService.kt:9-16]
    → ProbeRunner(applicationContext).run(intent)
    │
    ▼
ProbeRunner.run()                       [ProbeRunner.kt:29-103]
    → runs probe(s) → List<ProbeResult>
    → logs each result via Log.i(TAG, ...)      [TAG = "Phase0Probe", line 80-84]
    → if output=="json": JsonWriter.write() → last.json
    → Phase0StatusStore.recordRun() → sendBroadcast(ACTION_PROBE_COMPLETE)
```

**THE ASYNC PROBLEM**: `Phase0ProbeReceiver` delegates to `JobIntentService`. The `am broadcast` command returns immediately (exit 0) before any probe work starts. The result is **only** available via:

1. **logcat** — every `ProbeResult` is logged at `Log.i("Phase0Probe", ...)` but as a single flat line per result, not structured JSON.
2. **last.json** — written to `getExternalFilesDir(null)/zeehud_phase0/last.json` by `JsonWriter.write()` [JsonWriter.kt:62-63], but only if `output=json` was passed AND the async job has completed.
3. **ACTION_PROBE_COMPLETE broadcast** — fired after each run by `Phase0StatusStore.recordRun()` [Phase0StatusStore.kt:26-35] with extras: `timestamp`, `probes`, `track`, `total`, `success`, `output` (path to last.json). Received by `MainActivity`'s runtime-registered receiver.

**Readback in phase0**: The CLI scripts use `adb shell am broadcast`, wait a fixed time, then either:
- `adb logcat -s Phase0Probe -d` — screen-scrape one-liner per result
- `adb shell run-as com.zeekr.phase0 cat shared_prefs/phase0_status.xml` — check status metadata
- `adb shell cat /storage/emulated/0/Android/data/com.zeekr.phase0/files/zeehud_phase0/last.json` — pull the JSON

All of these are **non-deterministic**: you do not know when the job has completed.

---

## 3. JsonWriter Output Format (JsonWriter.kt:14-87)

File written to: `<externalFilesDir>/zeehud_phase0/last.json` (always named `last.json`, overwritten each run).

Schema:

```json
{
  "timestamp": "2026-06-11T12:00:00Z",
  "device": {
    "emulator": false,
    "model": "...",
    "fingerprint": "...",
    "sdk": 32,
    "release": "12"
  },
  "results": [
    {
      "name": "BcmFunction",
      "success": true,
      "message": "left=0 right=0 hazard=0",
      "timestamp": "...",
      "track": "a",
      "probe_group": "signals",
      "probe_name": "bcm",
      "error_type": null,
      "error_message": null,
      "data": {
        "source": "bcm",
        "signals": { "left": 0, "right": 0, "hazard": 0 }
      }
    }
  ]
}
```

`ProbeResult` data class fields (`ProbeResult.kt:5-16`): `name`, `success`, `message`, `timestamp`, `track`, `probeGroup`, `probeName`, `errorType`, `errorMessage`, `data: Map<String, Any?>`.

---

## 4. Phase0StatusStore — Lightweight Run-Metadata Channel

`Phase0StatusStore.kt` persists last-run metadata and fires `ACTION_PROBE_COMPLETE = "com.zeekr.phase0.PROBE_COMPLETE"` broadcast. This is **not** the probe results themselves — only summary metadata:

- `timestamp`, `probes`, `track`, `total` (count), `success` (count), `output` (absolute path to last.json)

The `output` path extra is the only link from the broadcast back to the JSON file. The broadcast itself cannot carry the full result payload.

---

## 5. KEY GAPS — Why Phase0 Is Async-Only

The core limitation is `Phase0ProbeReceiver` uses `JobIntentService.enqueueWork()`. The `BroadcastReceiver.onReceive()` returns before any work starts. There is **no mechanism** in phase0 to return data from the probe run to the caller synchronously.

Android provides two mechanisms that would allow synchronous/ordered return:

### Option A: Ordered Broadcast with `setResultExtras()` (recommended for small payloads)

`BroadcastReceiver.setResultExtras(Bundle)` is only callable on a receiver that was invoked by `sendOrderedBroadcast()`. The caller uses `am broadcast` which uses `sendBroadcast()` (unordered), so this is **not directly usable from ADB**. However, a `ContentProvider` or a new `Service` with `startActivityForResult` semantics can be the synchronous endpoint instead.

**Better ADB-compatible approach**: expose a `ContentProvider` or a dedicated `Service` with `onBind()` that allows synchronous query.

### Option B: Dedicated "dump" ContentProvider (recommended)

Add a `ContentProvider` with a custom URI scheme. `adb shell content query --uri content://com.zee.hud/state` runs synchronously in the app process and returns a `Cursor`. The provider reads from in-memory state (SignalStore + a new AppStateSnapshot singleton) and returns immediately.

### Option C: `am broadcast` with `--receiver-permission` + result-code trick

`adb shell am broadcast` with `-a ACTION` to a `BroadcastReceiver` that calls `setResultData()` / `setResultExtras()` — but only works if the broadcast is sent as **ordered** AND `adb shell` supports reading result extras (it prints `result=0 data="..."` for ordered broadcasts). Confirmed Android behavior: `am broadcast` prints the final result for ordered broadcasts.

---

## 6. CONCRETE DESIGN: Synchronous Structured Dump for the New App

### Design goal

Replace the async logcat/file readback with: **one ADB command returns deterministic JSON before the shell prompt returns**.

### Recommended: Ordered Broadcast to a manifest BroadcastReceiver

The new app's `SimChannelReceiver` (replacing phase0's `SimulateReceiver`) handles both injection and dump in a single ordered broadcast path.

**Key insight**: `adb shell am broadcast` sends an **unordered** broadcast by default, but it also prints the final result code/data for **ordered** broadcasts if invoked via a result-receiver. However, ordered broadcasts require the sender to send ordered. ADB `am broadcast` does not support this directly.

**Correct approach — ContentProvider dump endpoint**:

```
# Inject signal (fire-and-forget, same as phase0)
adb shell am broadcast \
  -a com.zee.hud.SIMULATE \
  -n com.zee.hud/.harness.SimulateReceiver \
  --es signal LEFT

# Synchronous dump — returns immediately with JSON in stdout
adb shell content query \
  --uri "content://com.zee.hud.debug/state" \
  --projection json
```

**Android ContentProvider** executes `query()` synchronously in the app's process (via Binder from `content` shell tool). The provider reads from the in-memory `SignalStore` and a new `NativeStateSnapshot` singleton, serialises to JSON, and returns it as a single-row Cursor with a `json` column.

**Alternative — ordered broadcast with result-extras**:

```bash
# adb shell am broadcast supports --receiver-permission and prints
# Broadcast completed: result=0, data="..."
# for ordered broadcasts sent with sendOrderedBroadcast internally.
# Workaround: make SimulateReceiver also handle a DUMP action via
# a goAsync() + setResultData(json) pattern — but this only works
# if called via sendOrderedBroadcast, not the ADB am broadcast tool.
```

Since `am broadcast` from ADB always sends unordered, `setResultExtras()` is not readable from the CLI. **ContentProvider is the correct choice.**

### Concrete implementation plan for new app

#### A. Retain phase0's `SignalStore` + `SimulateReceiver` pattern unchanged

- Copy `SignalStore.kt` verbatim (or adapt for additional fields: speed, charge).
- Copy `SimulateReceiver.kt` verbatim but rename action to `com.zee.hud.SIMULATE`.
- Add new signal fields to `SignalState`: `speedKmh: Float`, `socPercent: Float`, `chargingWatts: Float`.
- Add new `applyCommand` cases: `SPEED=<float>`, `SOC=<float>`, `CHARGE=<float>` (new extra or parsed value format).

#### B. New: `DebugStateProvider` — synchronous dump ContentProvider

```kotlin
class DebugStateProvider : ContentProvider() {
    override fun query(uri: Uri, projection: Array<String>?, ...): Cursor? {
        val snapshot = buildSnapshot()  // reads SignalStore + NativeState
        val json = snapshot.toJson()
        val cursor = MatrixCursor(arrayOf("json"))
        cursor.addRow(arrayOf(json))
        return cursor
    }

    private fun buildSnapshot(): AppStateSnapshot {
        val signals = SignalStore.get(requireContext())
        return AppStateSnapshot(
            signals = signals,
            simEnabled = SignalStore.isSimulated(requireContext()),
            timestamp = Instant.now().toString()
        )
    }
}
```

Manifest entry:
```xml
<provider
    android:name=".harness.DebugStateProvider"
    android:authorities="com.zee.hud.debug"
    android:exported="true"
    android:enabled="true" />
```

CLI usage:
```bash
adb shell content query --uri content://com.zee.hud.debug/state
# stdout: Row: 0 json={"signals":{"left":true,...},"sim_enabled":true,...}
```

Or with `jq`:
```bash
adb shell content query --uri content://com.zee.hud.debug/state \
  | sed 's/^.*json=//; s/ *$//' | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read()), indent=2))"
```

#### C. New: `NativeStateStore` — in-memory snapshot of native service state

The new app's `CarSignalsService` writes its most-recently-seen native values to a `NativeStateStore` singleton whenever it receives an AdaptAPI callback. `DebugStateProvider.query()` reads from this store. This gives the CLI a "what does the native layer currently know?" dump without triggering new probe work.

```kotlin
object NativeStateStore {
    @Volatile var latestBlinker: SignalState = SignalState(false, false, false)
    @Volatile var latestSpeedKmh: Float? = null
    @Volatile var latestSocPercent: Float? = null
    @Volatile var latestChargingWatts: Float? = null
    @Volatile var nativeApiConnected: Boolean = false
    @Volatile var lastUpdateMs: Long = 0L
}
```

#### D. Probe-runner (optional, for T2 sweep compatibility)

If the new app still wants a long-running probe sweep, keep the JobIntentService pattern for that, but make `output=json` + the fixed path the standard so the CLI can poll `content://com.zee.hud.debug/probe_last` which just reads the latest `last.json` path from a store and returns it:

```bash
# Trigger async probe sweep
adb shell am broadcast -a com.zee.hud.PROBE --es probes signals --es output json

# Poll until complete, then dump (synchronous)
adb shell content query --uri content://com.zee.hud.debug/probe_last
```

---

## 7. Complete Signal Table for New SimulateReceiver

Augmented from phase0 SignalStore to cover all CarSignals fields:

| `value` extra | Effect |
|--------------|--------|
| `SIM_ON` | Enable simulated mode — native API reads bypassed |
| `SIM_OFF` | Disable simulated mode |
| `LEFT` | left blinker on, right off, hazard off |
| `RIGHT` | right blinker on, left off, hazard off |
| `HAZARD` | both blinkers on |
| `OFF` | all blinkers off |
| `SPEED=<float>` | Set simulated vehicle speed in km/h |
| `SOC=<float>` | Set simulated SoC in percent (0-100) |
| `CHARGE=<float>` | Set simulated charge power in watts |

These additions are not in phase0; they must be implemented in the new app's `SignalStore`.

---

## 8. Key VehicleProperty IDs for Signal Injection Fidelity (from phase0 probes)

From `CarPropertyProbe.kt:202-217` (Tier 0/1 confirmed-live IDs):

| Signal | VHAL property ID | Type |
|--------|-----------------|------|
| Turn signal state | `0x11400408` (`TURN_SIGNAL_STATE`) | Int32 |
| Hazard lights state | `0x11400E03` (`HAZARD_LIGHTS_STATE`) | Int32 |
| Vehicle speed | `0x11600207` (`PERF_VEHICLE_SPEED`) | Float |
| EV battery level | `0x11600309` (`EV_BATTERY_LEVEL`) | Float |
| Battery charge rate | `0x1160030C` (`EV_BATTERY_INSTANTANEOUS_CHARGE_RATE`) | Float |
| Range remaining | `0x11600308` (`RANGE_REMAINING`) | Float |

From `BcmFunctionProbe.kt:22-25` (AdaptAPI BCM function IDs):

| Signal | AdaptAPI function ID | Notes |
|--------|---------------------|-------|
| BCM left blinker | `0x21051100` | `ICarFunction.getFunctionValue()` |
| BCM right blinker | `0x21051200` | |
| BCM hazard | `0x21050f00` | |

From `EnergyProbe.kt:126-162` (confirmed-live on-car via getprop):

| Signal | AdaptAPI function ID | Notes |
|--------|---------------------|-------|
| Charging SoC | `0x24100200` | `CHARGE_FUNC_CHARGING_SOC` (%) |
| Charging plug state | `0x24130200` | 12-state enum |
| Charging voltage | `0x24140100` | V |
| Charging current | `0x24140200` | A |
| Charging power | `0x241E0500` | kW |

---

## 9. HudProxyClient — Binder Synchronous Read Path (Already Exists)

`HudProxyClient.kt` already implements a synchronous binder transact pattern that returns a `Bundle` directly:

```kotlin
// ProxyHandle.transact() — line 110-130 in HudProxyClient.kt
binder.transact(code, data, reply, 0)  // blocks until service responds
reply.readException()
val hasResult = reply.readInt() != 0
return if (hasResult) Bundle.CREATOR.createFromParcel(reply) else null
```

This proves the Zeekr environment supports synchronous binder IPC from external processes (via `bindService`). The new `DebugStateProvider` approach is simpler than binder but the binder pattern is proven-working if a richer API surface is needed.

---

## 10. CarAppHostReceiver — `get_settings` Pattern (Phase0 Precedent for Sync Dump)

`CarAppHostReceiver.kt:69-72` already has a `get_settings` action that reads `HudSettings` synchronously in `onReceive()` and writes to **logcat only**:

```kotlin
"get_settings" -> {
    val settings = HudSettings.load(context)
    Log.i(TAG, "Current HUD settings: $settings")
}
```

This is the only "dump" pattern in phase0 — and it confirms that the phase0 team knew the synchronous-in-onReceive pattern works, but chose logcat as the output channel. The upgrade is to replace `Log.i` with `setResultData(json)` (for ordered broadcast) or with a ContentProvider (for `adb shell content query`).

---

## 11. Permissions Required

From `AndroidManifest.xml` (phase0):

- Signal/blinker reads: `android.car.permission.CAR_EXTERIOR_LIGHTS`, `android.car.permission.CAR_PROPERTY`
- New app must also declare these.
- `DebugStateProvider` can be `android:exported="true"` without a special permission since it is debug-only and returns no sensitive PII; the new app should gate it behind `android:debuggable="true"` or use `BuildConfig.DEBUG`.

---

## Summary: Phase0 → New App Migration Mapping

| Phase0 component | New app equivalent | Change needed |
|-----------------|-------------------|---------------|
| `SimulateReceiver` + `SIMULATE` action | `SimulateReceiver` + `com.zee.hud.SIMULATE` | Add SPEED/SOC/CHARGE commands |
| `SignalStore` (blinker-only) | `SignalStore` (blinker + speed + soc + charge) | Extend `SignalState` data class |
| `Phase0ProbeReceiver` + `JobIntentService` | Keep for long sweeps; drop for state dump | N/A |
| `JsonWriter` → `last.json` | Reuse verbatim | Change prefs/file path prefix |
| `Phase0StatusStore` | Retain `ACTION_PROBE_COMPLETE` broadcast | No change |
| logcat readback (async, fragile) | `DebugStateProvider` ContentProvider | **New** — key deliverable of ADR 0004 |
| N/A | `NativeStateStore` in-memory snapshot | **New** — feeds ContentProvider |


## Lift-ready artifacts

### SimulateReceiver
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/harness/SimulateReceiver.kt`
- **What:** BroadcastReceiver that accepts com.zeekr.phase0.SIMULATE intents with 'value' extra (SIM_ON, SIM_OFF, LEFT, RIGHT, HAZARD, OFF) and delegates to SignalStore
- **Reuse:** Copy verbatim; rename action string to com.zee.hud.SIMULATE; extend the 'else' branch to parse SPEED=<float>, SOC=<float>, CHARGE=<float> commands and write them to the extended SignalStore

### SignalStore
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/harness/SignalStore.kt`
- **What:** Singleton in-memory + SharedPrefs store for simulated signal state. Holds SignalState(left, right, hazard) + sim_enabled flag. Thread-safe via @Volatile + @Synchronized.
- **Reuse:** Copy the class; extend SignalState data class to add speedKmh:Float, socPercent:Float, chargingWatts:Float fields; add corresponding SharedPrefs keys and applyCommand() cases; rename prefs file to hud_signal_store in the new package

### ProbeResult
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/ProbeResult.kt`
- **What:** Canonical result data class: name, success, message, timestamp, track, probeGroup, probeName, errorType, errorMessage, data:Map<String,Any?>
- **Reuse:** Copy verbatim; this is the schema that JsonWriter serialises to last.json — keep field names identical so existing JSON consumers (zee_drive.py) work unchanged

### JsonWriter
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/output/JsonWriter.kt`
- **What:** Writes List<ProbeResult> to <externalFilesDir>/zeehud_phase0/last.json with device metadata header. Uses org.json, no external deps.
- **Reuse:** Copy verbatim into com.zee.hud.output.JsonWriter; update the output subdirectory from 'zeehud_phase0' to match new app package if desired; output schema is already stable

### Phase0StatusStore
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/Phase0StatusStore.kt`
- **What:** Persists probe-run metadata (timestamp, probes, track, total, success, output path) to SharedPrefs and fires ACTION_PROBE_COMPLETE broadcast after each run
- **Reuse:** Copy; rename constants to com.zee.hud.PROBE_COMPLETE; this gives the UI and any polling observer a lightweight signal that a new last.json is available without opening the file

### Phase0ProbeReceiver + Phase0ProbeJobIntentService
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/Phase0ProbeReceiver.kt`
- **What:** Manifest BroadcastReceiver that enqueues probe work to a JobIntentService. Handles com.zeekr.phase0.PROBE broadcasts. Async — does not block the caller.
- **Reuse:** Port the pattern for long-running sweeps only; do NOT use for synchronous state dumps. For the synchronous dump path, use a ContentProvider instead (see DebugStateProvider design in report). Register as com.zee.hud.PROBE in new app.

### HudProxyClient (binder transact pattern)
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/proxy/HudProxyClient.kt`
- **What:** Synchronous Binder IPC client proving that binder.transact() returns data synchronously from an external process on this DHU. Uses bindService + spin-wait then raw Parcel transact.
- **Reuse:** Do not copy the launcher-proxy-specific parts; reuse the ProxyHandle.transact() pattern (lines 110-130) as a reference implementation if you ever need a richer synchronous IPC beyond ContentProvider

### BlinkerOverlayView (SignalStore polling pattern)
- **Source:** `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/carapp/BlinkerOverlayView.kt`
- **What:** Self-contained HUD blinker View that polls SignalStore.get(context) from a HandlerThread at a fixed interval. Falls back to simulated state when isSimulated() is true.
- **Reuse:** Port the HandlerThread+SignalStore polling pattern into the Flutter engine's Kotlin side. The blinker's binary signal (left/right/hazard/off) maps cleanly to a Dart stream via Flutter MethodChannel or EventChannel.


## Concrete API surface

- com.zeekr.phase0.SIMULATE (BroadcastReceiver action — signal injection)
- com.zeekr.phase0.PROBE (BroadcastReceiver action — async probe trigger)
- com.zeekr.phase0.PROBE_COMPLETE (broadcast action fired on probe completion)
- SimulateReceiver.EXTRA_VALUE = "value" (String extra carrying command token)
- SignalStore.applyCommand(context, command) — writes LEFT/RIGHT/HAZARD/OFF to prefs
- SignalStore.setSimulatedEnabled(context, enabled) — toggles sim mode
- SignalStore.get(context): SignalState — reads current blinker state
- SignalStore.isSimulated(context): Boolean
- SignalState(left, right, hazard) — data class
- ProbeRunner.ACTION_PROBE = "com.zeekr.phase0.PROBE"
- ProbeRunner.EXTRA_PROBES = "probes" (values: all/signals/energy/display/system/carapp/locale/...)
- ProbeRunner.EXTRA_SOURCE = "source" (carlight/bcm/turnsignal/sweep/...)
- ProbeRunner.EXTRA_OUTPUT = "output" ("json" triggers JsonWriter)
- ProbeRunner.EXTRA_TRACK = "track" ("a" or "b")
- ProbeRunner.EXTRA_SWEEP_MS = "sweep_ms" (Long, default 12000)
- ProbeRunner.EXTRA_SWEEP_INTERVAL_MS = "sweep_interval_ms" (Long, default 200)
- Phase0StatusStore.ACTION_PROBE_COMPLETE = "com.zeekr.phase0.PROBE_COMPLETE"
- Phase0StatusStore.EXTRA_TIMESTAMP/PROBES/TRACK/TOTAL/SUCCESS/OUTPUT
- Phase0StatusStore.recordRun(probes, track, totalCount, successCount, outputPath)
- Phase0StatusStore.latest(): ProbeRunStatus
- JsonWriter.write(context, results): File? — writes to <externalFilesDir>/zeehud_phase0/last.json
- ProbeResult.data: Map<String, Any?> — arbitrary per-probe structured data
- CarAppHostReceiver.ACTION_CARAPP_HOST = "com.zeekr.phase0.CARAPP_HOST"
- CarAppHostReceiver action=get_settings — dumps HudSettings to logcat (sync in onReceive, logcat-only output)
- HudProxyClient.DESCRIPTOR = "com.zeekr.carlauncher.proxy.IHudProxy"
- HudProxyClient.ProxyHandle.getSignal(signalId): Bundle? — synchronous binder transact
- HudProxyClient.ProxyHandle.getFunction(functionId): Bundle?
- HudProxyClient.ProxyHandle.getSensor(sensorId): Bundle?
- CarLightProbe: ID_LEFT=0x401b, ID_RIGHT=0x401c, ID_HAZARD=0x4029 (CarLightYfveManager)
- BcmFunctionProbe: BCM_LEFT=0x21051100, BCM_RIGHT=0x21051200, BCM_HAZARD=0x21050f00 (AdaptAPI ICarFunction)
- TURN_SIGNAL_STATE VHAL property 0x11400408
- HAZARD_LIGHTS_STATE VHAL property 0x11400E03
- PERF_VEHICLE_SPEED VHAL property 0x11600207
- EV_BATTERY_LEVEL VHAL property 0x11600309
- EV_BATTERY_INSTANTANEOUS_CHARGE_RATE VHAL property 0x1160030C
- CHARGE_FUNC_CHARGING_SOC AdaptAPI function 0x24100200
- CHARGE_FUNC_CHARGING_WORK_VOLTAGE AdaptAPI function 0x24140100
- CHARGE_FUNC_CHARGING_WORK_CURRENT AdaptAPI function 0x24140200
- CHARGE_FUNC_CHARGING_WORK_POWER AdaptAPI function 0x241E0500
- hud_signal_store (SharedPreferences name for SignalStore)
- phase0_status (SharedPreferences name for Phase0StatusStore)

## Risks

- phase0's SIMULATE receiver only covers blinker signals; speed, SoC and charge injection must be added from scratch — no existing test coverage or ADB examples for those paths
- JobIntentService is deprecated since API 30; the new app should use WorkManager or a plain coroutine-based ForegroundService for long probe sweeps, not JobIntentService
- The logcat readback path is entirely unreliable as a machine-readable channel: log lines from concurrent probe groups interleave, there is no end-of-run marker readable by the CLI without grep+timestamp heuristics
- last.json is always overwritten (single file, no run history); if two probes run concurrently the file is non-deterministic — the ContentProvider design must serialize access
- ContentProvider query() runs on the Binder thread pool, not the main thread — SignalStore reads must be thread-safe (they are @Volatile in phase0, which is sufficient for reads)
- adb shell content query strips non-ASCII from Cursor column values on some Android versions; JSON payload must be ASCII-safe (escape non-ASCII in signal names/error messages)
- Phase0 sets android:exported=true on both SimulateReceiver and Phase0ProbeReceiver with no permission guard — any app on the device can inject arbitrary signals; the new app should add a signature-level permission for the production build, keeping exported=true only for debug builds
- getExternalFilesDir() returns null if external storage is not mounted (e.g. early boot) — JsonWriter handles this by falling back to filesDir, but the adb pull path differs; DebugStateProvider avoids this entirely by returning in-memory data
- EXTRA_VALUE = 'value' in SimulateReceiver but HUD.md line 156 shows '--es command LEFT' — the doc is wrong/stale; new code must use 'value', not 'command'
- HudProxyClient depends on ecarx.launcher3 package being installed; on emulator or non-Zeekr devices it silently returns null — all Track B probe results will show service_missing errors on T2 emulator without the launcher proxy APK

## Open questions

- Should the new SimulateReceiver accept speed/SoC/charge as separate extras (--ef speed_kmh 60.0 --ef soc_pct 80.0) or as a single 'value' string token like 'SPEED=60.0'? The token-string form is consistent with phase0 but loses am-broadcast type safety.
- Should DebugStateProvider expose both /state (in-memory sim state) and /probe_last (path + summary of last async probe run) as separate URIs, or merge them into one response?
- Does the new app's CarSignalsService need to write to NativeStateStore on every AdaptAPI callback, or only on demand when the ContentProvider is queried? On-demand avoids lock contention but requires synchronous AdaptAPI reads inside the Binder thread.
- Phase0's BlinkerOverlayView polls SignalStore directly (bypasses the native API when sim is on). In the new Flutter app, should the Kotlin side poll SignalStore and push events to Flutter via EventChannel, or should Flutter poll via MethodChannel?
- The probe sweep (signals/energy/etc.) takes up to 12 seconds by default — should the new app's PROBE broadcast accept a 'callback_action' extra so the CLI can register a one-shot reply receiver instead of polling for last.json?
- CarLightYfveManager IDs (0x401b/0x401c/0x4029) are Zeekr-private and not in AOSP VHAL; are these the same on the production DHU firmware as on the car where phase0 was validated?
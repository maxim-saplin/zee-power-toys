---
status: done
labels: [foundation, android, car-signals]
created: 2026-06-11
satisfies: foundation          # implements ADR 0002 (env-selected adapters) / 0004 (native channel)
blocked-by: [0003, 0004]
modules: [CarSignals, FeedbackLoop]
tier: T2
---

# 0005 — Environment-selected CarSignals: AdaptAPI ↔ simulator + native feedback channel

## Block scope
Make **live car signals real on Android** (ADR 0002 single-APK, environment-selected adapters): the native side auto-selects **real AdaptAPI** when present (car) or a **native simulator** when absent (emulator), with an ADB override. A type-safe **Pigeon** bridge carries signal events native→Dart into a `NativeCarSignals` adapter (injected via Riverpod on Android, replacing the Dart fake). The simulator is driven by **ADB broadcasts** (phase0 `SIMULATE` pattern) — this is the **native channel** of the Feedback Loop (ADR 0004): `inject` descends from the T1 Dart-fake to a real T2 broadcast→native→bridge→Dart path. A **synchronous structured dump** returns native signal state as JSON.

## Touches
- **Satisfies:** Foundation — ADR 0002 (auto-select adapter, one APK, ADB override), ADR 0004 (native ADB/broadcast injection + sync dump), ADR 0003 (CarSignals host swaps per tier; Dart brain unchanged).
- **Modules:** CarSignals (native + Dart adapter), FeedbackLoop (T2 native channel).
- **ADRs:** 0002, 0004, 0003.

## Grounding — port from phase0
- AdaptAPI access (reflection, IDs, units, listeners): [`docs/knowledge/car-signals-adaptapi.md`](../knowledge/car-signals-adaptapi.md). `com.ecarx.xui.adaptapi.car.Car.create(ctx)` → `getSensorManager`/`getICarFunction`; speed `0x00100100` (m/s×3.6), blinker L/R `0x21051100`/`0x21051200`, hazard = L&&R, charge state `0x00201500`, battery level `0x00100A00`/SoC `0x00404000`/temp `0x00102A00`, charge V/A/kW `0x24140100`/`0x24140200`/`0x2420C000` (zone `0x80000000`), power-flow `0x24010100`. Everything via `ReflectionUtils` (SDK is a system class, not a compile dep).
- Broadcast inject + sync dump: [`docs/knowledge/feedback-loop-native-channel.md`](../knowledge/feedback-loop-native-channel.md) (phase0 `SimulateReceiver`/`SignalStore`; upgrade async readback → `setResultExtras` synchronous JSON).

## What to build
- **Pigeon bridge** (`pigeons/car_signals.dart` + generated): native→Dart `CarSignalsFlutterApi` (event callbacks: speed/blinker/charge/battery/powerFlow) + Dart→native `CarSignalsHostApi` (`start()`, `snapshot()`).
- **Native** (`android/.../carsignals/`): `CarSignalSource` interface; `AdaptApiCarSignals` (reflection, IDs above; code-complete, **live path verified on-car only**); `SimulatedCarSignals` (in-memory, default on emulator). Auto-select: try `Car.create`; on failure/absence → simulator; ADB override via intent extra / `setprop`. Wire into `MainActivity` on the DHU engine.
- **Native broadcast channel**: a `SimulateReceiver` (`com.zeepowertoys.SIMULATE`, extras `kind`/`value`) → updates `SimulatedCarSignals` → emits over the bridge. A `dump` action (broadcast `setResultExtras` JSON, or a small dump method) returns current native signal state.
- **Dart** (`lib/services/adapters/native_car_signals.dart`): `NativeCarSignals implements CarSignals` — subscribes to the Pigeon FlutterApi, emits `CarSignalEvent`s, maintains `CarSnapshot`. Inject via `ProviderScope.overrides` on Android (T1 desktop keeps `FakeCarSignals`).
- **Feedback Loop** (`dev/feedback_loop.py`): implement the **T2 native channel** — `inject` → `adb am broadcast -a com.zeepowertoys.SIMULATE --es kind <k> --es value <v>`; native-state `dump` → parse the broadcast result JSON. `--tier t2`/`--serial` selects it. (T1 keeps VM-service inject.)

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] **T2 (emulator):** an **ADB broadcast** `SIMULATE kind=speed value=80` (NOT ext.zee.inject) flows native-sim → bridge → Dart → `readViewModel` on **both** dhu+hud = 80. blinker=left + charge{760/55/42} likewise. — artifact: confirmed live; `am broadcast -n <pkg>/.carsignals.SimulateReceiver -a com.zeepowertoys.SIMULATE --es kind speed --es value 80`.
- [x] **T2:** native sync dump returns current signal state JSON via ordered-broadcast `setResultData`. — artifact: `DUMP` → `{"speedKmh":80,"blinker":"left","charging":true,"chargeVolts":760.0,...}`.
- [x] Auto-select picks the **simulator** on the emulator (AdaptAPI absent), logged (`CarSignals source = Simulated (auto-detected: AdaptAPI probe returned false)`); `setprop persist.zee.carsignals sim|adapt` override respected.
- [x] AdaptAPI adapter code-complete; IDs/units verified vs the knowledge doc (live path deferred to T3). 13 Dart unit tests for event decoding (`flutter test`: 23 total green).
- [x] T1 not regressed (analyze clean, 23 tests, build linux ok); one APK (no flavors).
- [x] Principles: simulator emits only on change (no polling); AdaptAPI listeners registered once; reflection guarded.

## Reconciliation
Confirmed by the orchestrator (Opus) on T2, 2026-06-11.
1. **Bridge: EventChannel + MethodChannel, not Pigeon** (ADR 0002 reconciled in-doc). `zee/car_signals/events` (EventChannel, native→Dart event maps) + `zee/car_signals` (MethodChannel, `start`/`snapshot`). Idiomatic for an event stream; avoids the `*.g.dart` ignore conflict. Schema = the Pigeon contract realized in-channel; migration later is mechanical.
2. **Background-broadcast restriction (Android 8+):** `am broadcast` MUST target the component explicitly — `-n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver` — or it's silently dropped. Baked into `feedback_loop.py` `T2NativeChannel` and documented in the contract.
3. **ADB override:** `setprop persist.zee.carsignals sim|adapt` (empty = auto-detect). **SIMULATE/DUMP contract** documented in [`docs/feedback-loop-contract.md`](../feedback-loop-contract.md).
4. **HUD CarSignals on T2:** the HUD engine has no native bridge — the HUD isolate keeps a relay-fed `FakeCarSignals`; only the DHU engine hosts the native source, and DHU relays events to HUD over the hub (consistent with ADR 0003).
5. **AdaptAPI charge V/A/kW** arrive via the `IFunctionValueWatcher.onCustomizeFunctionValueChanged` callback (zone `0x80000000`); the exact watcher-registration API is a T3-verification item (guarded, non-fatal if it differs).

package com.zeepowertoys.zee_power_toys.carsignals

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// CarSignalsController — auto-selects AdaptAPI or Simulator; bridges native→Dart.
//
// Bridge: MethodChannel "zee/car_signals" for start()/snapshot();
//         EventChannel  "zee/car_signals/events" for streamed SignalEvents.
//
// ADR 0002: Pigeon was the first-choice bridge; EventChannel is used here
// because Pigeon's FlutterApi stream ergonomics require codegen wiring that
// fights the generated *.g.dart gitignore rule. The semantic contract is
// identical to the Pigeon spec: the same 5 event types (speed/blinker/charge/
// battery/powerFlow) are encoded as JSON maps over the EventChannel.
//
// ADB override: `adb shell setprop persist.zee.carsignals sim` forces simulator;
//               `adb shell setprop persist.zee.carsignals adapt` forces AdaptAPI.
//               Omitted or any other value = auto-detect at runtime.
class CarSignalsController(
    private val ctx: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val TAG = "ZEE"
    private val METHOD_CH = "zee/car_signals"
    private val EVENT_CH  = "zee/car_signals/events"

    // Hoisted main-thread handler — reused across all emitEvent() calls (QA4-3).
    private val mainHandler = Handler(Looper.getMainLooper())

    private val methodChannel = MethodChannel(messenger, METHOD_CH)
    private val eventChannel  = EventChannel(messenger, EVENT_CH)

    private var source: CarSignalSource? = null
    private var simSource: SimulatedCarSignals? = null
    private var eventSink: EventChannel.EventSink? = null
    private var started = false

    // Which source selectSource() actually picked — "adaptapi" | "simulated".
    // Surfaced to Dart (CarSignalSnapshot.source) so the UI can tell the user
    // whether they are looking at demo data or a real car, instead of the
    // decision being logged and nowhere else (Task 1 — signal-source honesty).
    private var sourceKind: String = "unknown"

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                Log.i(TAG, "CarSignals EventChannel: Dart listening")
                eventSink = sink
                // Seed Dart immediately — otherwise publishChargeState early-return /
                // missed ticks leave Diagnostics/HUD empty while AdaptAPI is live.
                seedSinkFromSnapshot()
            }
            override fun onCancel(arguments: Any?) {
                Log.i(TAG, "CarSignals EventChannel: Dart unsubscribed")
                eventSink = null
            }
        })
    }

    // Called from MainActivity.configureFlutterEngine after init.
    // auto-selects the source, logs the decision, and makes the simSource
    // reference available to SimulateReceiver.
    fun selectSource() {
        val override = runCatching {
            Runtime.getRuntime().exec(arrayOf("getprop", "persist.zee.carsignals"))
                .inputStream.bufferedReader().readLine()?.trim() ?: ""
        }.getOrElse { "" }

        val src: CarSignalSource = when {
            override == "sim" -> {
                Log.i(TAG, "CarSignals source = Simulated (ADB override persist.zee.carsignals=sim)")
                sourceKind = "simulated"
                SimulatedCarSignals()
            }
            override == "adapt" -> {
                Log.i(TAG, "CarSignals source = AdaptAPI (ADB override persist.zee.carsignals=adapt)")
                sourceKind = "adaptapi"
                AdaptApiCarSignals(ctx)
            }
            else -> {
                // Auto-detect: try AdaptAPI; fall back to Simulator on any failure.
                val adapApi = AdaptApiCarSignals(ctx)
                try {
                    if (adapApi.probe()) {
                        Log.i(TAG, "CarSignals source = AdaptAPI (auto-detected: Car.create succeeded)")
                        sourceKind = "adaptapi"
                        adapApi
                    } else {
                        Log.i(TAG, "CarSignals source = Simulated (auto-detected: AdaptAPI probe returned false)")
                        sourceKind = "simulated"
                        SimulatedCarSignals()
                    }
                } catch (t: Throwable) {
                    Log.i(TAG, "CarSignals source = Simulated (auto-detected: AdaptAPI probe threw: ${t.message})")
                    sourceKind = "simulated"
                    SimulatedCarSignals()
                }
            }
        }

        source = src
        if (src is SimulatedCarSignals) simSource = src
    }

    // Annotate a raw source snapshot with the resolved sourceKind before
    // handing it to Dart — the source objects themselves (AdaptApiCarSignals /
    // SimulatedCarSignals) know nothing about which one was selected; only
    // this controller does (selectSource() above).
    private fun snapshotWithSource(): CarSignalSnapshot? =
        source?.snapshot()?.copy(source = sourceKind)

    // MethodChannel handler — Dart calls start() and snapshot()
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                if (!started) {
                    started = true
                    source?.start { event -> emitEvent(event) }
                    // AdaptAPI seed runs inside start(); push again so Dart
                    // does not keep the empty onListen seed forever if the
                    // first Charge ticks are missed.
                    seedSinkFromSnapshot()
                }
                result.success(snapshotWithSource()?.toMap())
            }
            "snapshot" -> result.success(snapshotWithSource()?.toMap())
            // simulate — in-app equivalent of the SimulateReceiver ADB broadcast
            // (Block 0026, Developer Simulate screen). Reuses the same parsing
            // (SimulatorState.apply) and forwarding (onSimulatedEvent) as the
            // broadcast path, so it is a safe no-op when AdaptAPI is the live
            // source (simSource stays null — see onSimulatedEvent).
            "simulate" -> {
                val kind = call.argument<String>("kind")
                val value = call.argument<String>("value")
                val event = if (kind != null && value != null) {
                    SimulatorState.apply(kind, value)
                } else null
                if (event != null) onSimulatedEvent(event)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Push current native snapshot as discrete events so Dart/HUD catch up. */
    private fun seedSinkFromSnapshot() {
        val snap = source?.snapshot() ?: return
        Log.i(
            TAG,
            "CarSignals seed→Dart: charging=${snap.charging} kW=${snap.chargeKw} " +
                "pct=${snap.batteryPct} temp=${snap.batteryTempC}",
        )
        emitEvent(
            SignalEvent.Charge(
                snap.charging,
                snap.chargeVolts,
                snap.chargeAmps,
                snap.chargeKw,
            ),
        )
        val pct = snap.batteryPct
        if (pct != null) {
            emitEvent(SignalEvent.Battery(pct, snap.batteryTempC ?: 25.0))
        }
        snap.speedKmh?.let { emitEvent(SignalEvent.Speed(it)) }
        emitEvent(SignalEvent.Blinker(snap.blinker))
    }

    // Push a SignalEvent to Flutter via the EventChannel sink.
    private fun emitEvent(event: SignalEvent) {
        val sink = eventSink
        if (sink == null) {
            Log.w(TAG, "CarSignals emit dropped (no Dart sink): ${event::class.simpleName}")
            return
        }
        // Encode as a discriminated map — matches NativeCarSignals.dart decoder.
        val map: MutableMap<String, Any?> = when (event) {
            is SignalEvent.Speed -> mutableMapOf("type" to "speed", "kmh" to event.kmh)
            is SignalEvent.Blinker -> mutableMapOf("type" to "blinker", "state" to event.state)
            is SignalEvent.Charge -> mutableMapOf<String, Any?>(
                "type" to "charge",
                "charging" to event.charging,
                "volts" to event.volts,
                "amps" to event.amps,
                "kw" to event.kw,
            )
            is SignalEvent.Battery -> mutableMapOf(
                "type" to "battery",
                "levelPct" to event.levelPct,
                "tempC" to event.tempC,
            )
            is SignalEvent.PowerFlow -> mutableMapOf("type" to "powerFlow", "flow" to event.flow)
        }
        mainHandler.post {
            try {
                sink.success(map)
                if (event is SignalEvent.Charge) {
                    Log.i(TAG, "CarSignals →Dart charge charging=${event.charging} kW=${event.kw}")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "CarSignals sink.success failed", t)
            }
        }
    }

    // Called by SimulateReceiver when an ADB broadcast arrives.
    // Forwards the event to Flutter and updates SimulatorState (already done by receiver).
    fun onSimulatedEvent(event: SignalEvent) {
        simSource?.pushEvent(event)
    }

    fun tearDown() {
        source?.stop()
        source = null
        simSource = null
        methodChannel.setMethodCallHandler(null)
    }
}

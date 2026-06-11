package com.zeepowertoys.zee_power_toys.carsignals

import android.content.Context
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

    private val methodChannel = MethodChannel(messenger, METHOD_CH)
    private val eventChannel  = EventChannel(messenger, EVENT_CH)

    private var source: CarSignalSource? = null
    private var simSource: SimulatedCarSignals? = null
    private var eventSink: EventChannel.EventSink? = null
    private var started = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                Log.i(TAG, "CarSignals EventChannel: Dart listening")
                eventSink = sink
                // If already started (race on connect), replay nothing — next event will arrive.
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
                SimulatedCarSignals()
            }
            override == "adapt" -> {
                Log.i(TAG, "CarSignals source = AdaptAPI (ADB override persist.zee.carsignals=adapt)")
                AdaptApiCarSignals(ctx)
            }
            else -> {
                // Auto-detect: try AdaptAPI; fall back to Simulator on any failure.
                val adapApi = AdaptApiCarSignals(ctx)
                try {
                    if (adapApi.probe()) {
                        Log.i(TAG, "CarSignals source = AdaptAPI (auto-detected: Car.create succeeded)")
                        adapApi
                    } else {
                        Log.i(TAG, "CarSignals source = Simulated (auto-detected: AdaptAPI probe returned false)")
                        SimulatedCarSignals()
                    }
                } catch (t: Throwable) {
                    Log.i(TAG, "CarSignals source = Simulated (auto-detected: AdaptAPI probe threw: ${t.message})")
                    SimulatedCarSignals()
                }
            }
        }

        source = src
        if (src is SimulatedCarSignals) simSource = src
    }

    // MethodChannel handler — Dart calls start() and snapshot()
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                if (!started) {
                    started = true
                    source?.start { event -> emitEvent(event) }
                }
                result.success(null)
            }
            "snapshot" -> result.success(source?.snapshot()?.toMap())
            else -> result.notImplemented()
        }
    }

    // Push a SignalEvent to Flutter via the EventChannel sink.
    private fun emitEvent(event: SignalEvent) {
        val sink = eventSink ?: return
        // Encode as a discriminated map — matches NativeCarSignals.dart decoder.
        val map: Map<String, Any?> = when (event) {
            is SignalEvent.Speed -> mapOf("type" to "speed", "kmh" to event.kmh)
            is SignalEvent.Blinker -> mapOf("type" to "blinker", "state" to event.state)
            is SignalEvent.Charge -> mapOf(
                "type" to "charge",
                "charging" to event.charging,
                "volts" to event.volts,
                "amps" to event.amps,
                "kw" to event.kw,
            )
            is SignalEvent.Battery -> mapOf(
                "type" to "battery",
                "levelPct" to event.levelPct,
                "tempC" to event.tempC,
            )
            is SignalEvent.PowerFlow -> mapOf("type" to "powerFlow", "flow" to event.flow)
        }
        // EventSink.success must be called on the main thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            sink.success(map)
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

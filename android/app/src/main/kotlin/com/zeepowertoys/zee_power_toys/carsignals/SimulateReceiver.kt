package com.zeepowertoys.zee_power_toys.carsignals

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// SimulateReceiver — accepts ADB broadcasts to inject car signal values.
//
// Broadcast actions:
//   com.zeepowertoys.SIMULATE  — inject a signal (updates SimulatorState + emits to Flutter)
//   com.zeepowertoys.DUMP      — return current snapshot JSON in result data (ordered broadcast)
//
// SIMULATE extras:
//   kind   (String) — "speed" | "blinker" | "charge" | "battery" | "powerFlow"
//   value  (String) — kind-specific value:
//     speed:     "<kmh>"                           e.g. "80"
//     blinker:   "left" | "right" | "hazard" | "off"
//     charge:    "<bool>:<volts>:<amps>:<kw>"      e.g. "true:400.0:20.5:8.2" or "false"
//     battery:   "<pct>:<tempC>"                   e.g. "80:27.5"
//     powerFlow: "drive" | "regen" | "standstill" | "unknown"
//
// DUMP returns the current snapshot JSON via setResultData() for ordered broadcasts.
// For unordered ADB `am broadcast` the result data is printed to stdout:
//   "Broadcast completed: result=0, data=<json>"
//
// ADB examples:
//   # REQUIRED: use -n <component> so the broadcast is delivered even in background
//   # (Android 8+ blocks implicit broadcasts to manifest receivers in background)
//   adb -s emulator-5554 shell am broadcast \
//     -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
//     -a com.zeepowertoys.SIMULATE --es kind speed --es value 80
//   adb -s emulator-5554 shell am broadcast \
//     -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
//     -a com.zeepowertoys.SIMULATE --es kind blinker --es value left
//   adb -s emulator-5554 shell am broadcast \
//     -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
//     -a com.zeepowertoys.DUMP
//
// Controller reference: populated by MainActivity.configureFlutterEngine on the DHU engine.
// SimulateReceiver is registered in the manifest, so it survives FlutterEngine restarts.
class SimulateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("ZEE", "SimulateReceiver.onReceive action=${intent.action}")
        when (intent.action) {
            ACTION_SIMULATE -> handleSimulate(intent)
            ACTION_DUMP     -> handleDump()
            else            -> return
        }
    }

    private fun handleSimulate(intent: Intent) {
        val kind  = intent.getStringExtra(EXTRA_KIND)  ?: return
        val value = intent.getStringExtra(EXTRA_VALUE) ?: return
        Log.i("ZEE", "SIMULATE kind=$kind value=$value")
        val event = SimulatorState.apply(kind, value) ?: run {
            Log.w("ZEE", "SIMULATE: unrecognised kind=$kind or value=$value — ignored")
            return
        }
        // Push into the live source (no-op if AdaptAPI is selected)
        controllerRef?.onSimulatedEvent(event)
    }

    private fun handleDump() {
        val json = SimulatorState.snapshot().toJson()
        Log.i("ZEE", "DUMP: $json")
        // setResultData makes the JSON readable from ordered-broadcast callers.
        // For ADB `am broadcast` the data appears as:  result=0, data=<json>
        resultData = json
    }

    companion object {
        const val ACTION_SIMULATE = "com.zeepowertoys.SIMULATE"
        const val ACTION_DUMP     = "com.zeepowertoys.DUMP"
        const val EXTRA_KIND      = "kind"
        const val EXTRA_VALUE     = "value"

        // Set by MainActivity after CarSignalsController is constructed.
        // Weak ref not needed — the receiver only runs on the main thread and the
        // controller lives for the app process lifetime.
        @Volatile
        var controllerRef: CarSignalsController? = null
    }
}

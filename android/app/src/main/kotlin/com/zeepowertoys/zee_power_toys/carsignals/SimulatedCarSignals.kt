package com.zeepowertoys.zee_power_toys.carsignals

import android.util.Log

// Simulated CarSignalSource — used on emulator where AdaptAPI is absent.
// No always-on polling: emits only when the SIMULATE broadcast changes a value.
// The broadcast receiver calls [pushEvent]; this notifies the registered emitter.
class SimulatedCarSignals : CarSignalSource {
    private val TAG = "ZEE"
    private var emitter: ((SignalEvent) -> Unit)? = null

    override fun start(emit: (SignalEvent) -> Unit) {
        emitter = emit
        Log.i(TAG, "SimulatedCarSignals started — waiting for SIMULATE broadcasts")
        // No polling; events arrive via pushEvent() from SimulateReceiver.
    }

    override fun snapshot(): CarSignalSnapshot = SimulatorState.snapshot()

    override fun stop() {
        emitter = null
        Log.i(TAG, "SimulatedCarSignals stopped")
    }

    // Called by SimulateReceiver when a broadcast mutates SimulatorState.
    fun pushEvent(event: SignalEvent) {
        emitter?.invoke(event)
    }
}

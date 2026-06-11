package com.zeepowertoys.zee_power_toys.carsignals

// Internal interface for a provider of car signals.
// Either AdaptApiCarSignals (real car) or SimulatedCarSignals (emulator/default).
interface CarSignalSource {
    // Start emitting signals; [emit] is called on each change.
    fun start(emit: (SignalEvent) -> Unit)

    // Return current snapshot without starting the full listener cycle.
    fun snapshot(): CarSignalSnapshot

    // Release all resources / unregister listeners.
    fun stop()
}

// Typed events emitted by CarSignalSource implementations.
sealed class SignalEvent {
    data class Speed(val kmh: Int) : SignalEvent()
    data class Blinker(val state: String) : SignalEvent()    // off|left|right|hazard
    data class Charge(
        val charging: Boolean,
        val volts: Double?,
        val amps: Double?,
        val kw: Double?,
    ) : SignalEvent()
    data class Battery(val levelPct: Int, val tempC: Double) : SignalEvent()
    data class PowerFlow(val flow: String) : SignalEvent()   // unknown|drive|regen|standstill
}

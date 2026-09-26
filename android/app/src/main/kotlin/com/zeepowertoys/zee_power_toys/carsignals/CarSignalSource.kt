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
    /** Float SoC % (0.1% resolution) — 0118; HUD may still show int. */
    data class Battery(val levelPct: Double, val tempC: Double) : SignalEvent()
    data class PowerFlow(val flow: String) : SignalEvent()   // unknown|drive|regen|standstill
    data class DriveMode(val mode: String) : SignalEvent()   // unknown|eco|comfort|sport|other
    /** Adapt Energy Cons 1 kWh/100km — 0118. */
    data class Efficiency(val kwhPer100km: Double) : SignalEvent()
}

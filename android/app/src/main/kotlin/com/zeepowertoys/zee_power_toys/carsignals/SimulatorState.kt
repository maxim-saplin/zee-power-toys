package com.zeepowertoys.zee_power_toys.carsignals

import android.util.Log

// In-memory state for the native signal simulator.
// Written by SimulateReceiver (ADB broadcast); read by SimulatedCarSignals.
// Thread-safe: all fields @Volatile; compound updates serialized by [lock].
object SimulatorState {
    private val lock = Any()

    @Volatile var speedKmh: Int? = null
    @Volatile var blinker: String = "off"
    @Volatile var charging: Boolean? = null
    @Volatile var chargeVolts: Double? = null
    @Volatile var chargeAmps: Double? = null
    @Volatile var chargeKw: Double? = null
    @Volatile var batteryPct: Int? = null
    @Volatile var batteryTempC: Double? = null
    @Volatile var powerFlow: String = "unknown"

    fun snapshot() = CarSignalSnapshot(
        speedKmh = speedKmh,
        blinker = blinker,
        charging = charging,
        chargeVolts = chargeVolts,
        chargeAmps = chargeAmps,
        chargeKw = chargeKw,
        batteryPct = batteryPct,
        batteryTempC = batteryTempC,
        powerFlow = powerFlow,
    )

    // Apply a kind/value pair from the SIMULATE broadcast.
    // Returns the event that changed, or null if the value was unparseable.
    fun apply(kind: String, value: String): SignalEvent? = synchronized(lock) {
        Log.d("ZEE", "SimulatorState.apply kind=$kind value=$value")
        when (kind.lowercase()) {
            "speed" -> {
                val kmh = value.toIntOrNull() ?: return null
                speedKmh = kmh
                SignalEvent.Speed(kmh)
            }
            "blinker" -> {
                val state = when (value.lowercase()) {
                    "left" -> "left"
                    "right" -> "right"
                    "hazard" -> "hazard"
                    "off" -> "off"
                    else -> return null
                }
                blinker = state
                SignalEvent.Blinker(state)
            }
            "charge" -> {
                // value format: "true:400.0:20.5:8.2"  or "false"
                // true:<volts>:<amps>:<kw>
                val parts = value.split(":")
                val ch = parts.getOrNull(0)?.toBooleanStrictOrNull() ?: return null
                charging = ch
                chargeVolts = parts.getOrNull(1)?.toDoubleOrNull()
                chargeAmps = parts.getOrNull(2)?.toDoubleOrNull()
                chargeKw = parts.getOrNull(3)?.toDoubleOrNull()
                SignalEvent.Charge(ch, chargeVolts, chargeAmps, chargeKw)
            }
            "battery" -> {
                // value format: "<pct>:<tempC>"
                val parts = value.split(":")
                val pct = parts.getOrNull(0)?.toIntOrNull() ?: return null
                val temp = parts.getOrNull(1)?.toDoubleOrNull() ?: 25.0
                batteryPct = pct
                batteryTempC = temp
                SignalEvent.Battery(pct, temp)
            }
            "powerflow" -> {
                val flow = when (value.lowercase()) {
                    "drive" -> "drive"
                    "regen" -> "regen"
                    "standstill" -> "standstill"
                    else -> "unknown"
                }
                powerFlow = flow
                SignalEvent.PowerFlow(flow)
            }
            else -> null
        }
    }
}

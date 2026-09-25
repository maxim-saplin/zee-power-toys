package com.zeepowertoys.zee_power_toys.carsignals

// Snapshot of current native car signal state.
// Passed back to Dart via MethodChannel "snapshot" and used by the ContentProvider dump.
//
// [source] — which CarSignalSource is actually live behind this snapshot:
// "adaptapi" | "simulated". Populated by CarSignalsController from its own
// selectSource() decision (never re-derived here) so Dart/the UI can report
// the real signal source instead of leaving the user to guess whether they
// are looking at demo data or a real car (the emulator-vs-car confusion).
data class CarSignalSnapshot(
    val speedKmh: Int? = null,
    val blinker: String = "off",   // off | left | right | hazard
    val charging: Boolean = false,
    val chargeVolts: Double? = null,
    val chargeAmps: Double? = null,
    val chargeKw: Double? = null,
    val batteryPct: Int? = null,
    val batteryTempC: Double? = null,
    val powerFlow: String = "unknown",
    val driveMode: String = "unknown", // unknown|eco|comfort|sport|other
    val source: String = "unknown",   // adaptapi | simulated | unknown
) {
    fun toMap(): Map<String, Any?> = mutableMapOf(
        "speedKmh" to speedKmh,
        "blinker" to blinker,
        "charging" to charging,
        "chargeVolts" to chargeVolts,
        "chargeAmps" to chargeAmps,
        "chargeKw" to chargeKw,
        "batteryPct" to batteryPct,
        "batteryTempC" to batteryTempC,
        "powerFlow" to powerFlow,
        "driveMode" to driveMode,
        "source" to source,
    )

    fun toJson(): String = buildString {
        append("{")
        append("\"speedKmh\":${speedKmh ?: "null"},")
        append("\"blinker\":\"$blinker\",")
        append("\"charging\":$charging,")
        append("\"chargeVolts\":${chargeVolts ?: "null"},")
        append("\"chargeAmps\":${chargeAmps ?: "null"},")
        append("\"chargeKw\":${chargeKw ?: "null"},")
        append("\"batteryPct\":${batteryPct ?: "null"},")
        append("\"batteryTempC\":${batteryTempC ?: "null"},")
        append("\"powerFlow\":\"$powerFlow\",")
        append("\"driveMode\":\"$driveMode\",")
        append("\"source\":\"$source\"")
        append("}")
    }
}

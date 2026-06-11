package com.zeepowertoys.zee_power_toys.carsignals

// Snapshot of current native car signal state.
// Passed back to Dart via MethodChannel "snapshot" and used by the ContentProvider dump.
data class CarSignalSnapshot(
    val speedKmh: Int? = null,
    val blinker: String = "off",   // off | left | right | hazard
    val charging: Boolean? = null,
    val chargeVolts: Double? = null,
    val chargeAmps: Double? = null,
    val chargeKw: Double? = null,
    val batteryPct: Int? = null,
    val batteryTempC: Double? = null,
    val powerFlow: String = "unknown",
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "speedKmh" to speedKmh,
        "blinker" to blinker,
        "charging" to charging,
        "chargeVolts" to chargeVolts,
        "chargeAmps" to chargeAmps,
        "chargeKw" to chargeKw,
        "batteryPct" to batteryPct,
        "batteryTempC" to batteryTempC,
        "powerFlow" to powerFlow,
    )

    fun toJson(): String = buildString {
        append("{")
        append("\"speedKmh\":${speedKmh ?: "null"},")
        append("\"blinker\":\"$blinker\",")
        append("\"charging\":${charging ?: "null"},")
        append("\"chargeVolts\":${chargeVolts ?: "null"},")
        append("\"chargeAmps\":${chargeAmps ?: "null"},")
        append("\"chargeKw\":${chargeKw ?: "null"},")
        append("\"batteryPct\":${batteryPct ?: "null"},")
        append("\"batteryTempC\":${batteryTempC ?: "null"},")
        append("\"powerFlow\":\"$powerFlow\"")
        append("}")
    }
}

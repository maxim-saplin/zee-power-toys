package com.zeepowertoys.zee_power_toys.speedcam

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Runtime-registered receiver for YNavi [SpeedCamBroadcaster] intents
 * (`com.zeekr.phase0.SPEEDCAM_DATA`, package-targeted at toys).
 *
 * Must NOT be manifest-only — Android 12+ blocks implicit 3P broadcasts to
 * manifest receivers; register from FGS / Activity (same lesson as Phase0).
 */
class SpeedcamYnaviReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_SPEEDCAM_DATA) return

        val tMs = intent.getLongExtra("t_ms", System.currentTimeMillis())
        val count = if (intent.hasExtra("count")) intent.getIntExtra("count", -1) else -1
        val index = if (intent.hasExtra("index")) intent.getIntExtra("index", -1) else -1
        val hasBatch = intent.hasExtra("count") || intent.hasExtra("index") || intent.hasExtra("t_ms")

        // Heartbeat / clear — no lat/lon
        if (hasBatch && count == 0 && !intent.hasExtra("lat") && !intent.hasExtra("lon")) {
            lastBridgeFireEpochMs = tMs
            lastError = null
            emit(
                mapOf(
                    "kind" to "heartbeat",
                    "t_ms" to tMs,
                    "count" to 0,
                    "source" to (intent.getStringExtra("source") ?: "ynavi"),
                ),
            )
            return
        }

        val lat = intent.doubleOrFloat("lat")
        val lon = intent.doubleOrFloat("lon")
        if (lat.isNaN() || lon.isNaN()) {
            lastError = "invalid_coordinates"
            Log.w(TAG, "Ignoring SPEEDCAM_DATA without lat/lon")
            return
        }

        val speedLimit = intent.getIntExtra("speedLimit", -1)
        val distance = intent.doubleOrFloat("distance")
        val type = intent.getStringExtra("type") ?: "speed_camera"
        val tags = intent.getStringExtra("tags") ?: type
        val eventId = intent.getStringExtra("eventId")?.takeIf { it.isNotBlank() }
            ?: "${lat}_${lon}_$type"
        val source = intent.getStringExtra("source")?.takeIf { it.isNotBlank() }
            ?: if (hasBatch) "ynavi" else "live"

        lastBridgeFireEpochMs = tMs
        lastError = null
        sessionEventCount += 1

        emit(
            mapOf(
                "kind" to "cam",
                "t_ms" to tMs,
                "count" to count,
                "index" to index,
                "lat" to lat,
                "lon" to lon,
                "speedLimit" to speedLimit,
                "distance" to distance,
                "type" to type,
                "tags" to tags,
                "eventId" to eventId,
                "source" to source,
            ),
        )
        Log.i(TAG, "ynavi cam eventId=$eventId lat=$lat lon=$lon limit=$speedLimit dist=$distance")
    }

    private fun Intent.doubleOrFloat(key: String): Double {
        val d = getDoubleExtra(key, Double.NaN)
        if (!d.isNaN()) return d
        val f = getFloatExtra(key, Float.NaN)
        return if (f.isNaN()) Double.NaN else f.toDouble()
    }

    companion object {
        private const val TAG = "ZEE"
        const val ACTION_SPEEDCAM_DATA = "com.zeekr.phase0.SPEEDCAM_DATA"
        const val EVENT_CHANNEL = "zee/speedcam/ynavi"

        @Volatile var eventSink: EventChannel.EventSink? = null
        @Volatile var lastBridgeFireEpochMs: Long = 0L
        @Volatile var sessionEventCount: Int = 0
        @Volatile var lastError: String? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        fun emit(payload: Map<String, Any?>) {
            mainHandler.post {
                try {
                    eventSink?.success(payload)
                } catch (t: Throwable) {
                    Log.w(TAG, "ynavi EventChannel emit failed", t)
                }
            }
        }

        @Volatile private var processReceiver: SpeedcamYnaviReceiver? = null

        /** Idempotent process-wide register (FGS and/or Activity may call). */
        @Synchronized
        fun ensureRegistered(context: Context): SpeedcamYnaviReceiver {
            processReceiver?.let { return it }
            val appCtx = context.applicationContext
            val receiver = SpeedcamYnaviReceiver()
            val filter = IntentFilter(ACTION_SPEEDCAM_DATA)
            if (Build.VERSION.SDK_INT >= 33) {
                appCtx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                appCtx.registerReceiver(receiver, filter)
            }
            processReceiver = receiver
            Log.i(TAG, "SpeedcamYnaviReceiver registered (action=$ACTION_SPEEDCAM_DATA)")
            return receiver
        }

        fun register(context: Context): SpeedcamYnaviReceiver = ensureRegistered(context)

        fun unregister(context: Context, receiver: SpeedcamYnaviReceiver?) {
            // Keep process-wide registration while FGS/Activity churn — only clear sink.
            if (receiver == null) return
            Log.i(TAG, "SpeedcamYnaviReceiver unregister requested (kept process-wide)")
        }
    }
}

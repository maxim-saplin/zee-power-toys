package com.zeepowertoys.zee_power_toys.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Android [LocationManager] GPS/network fallback for Speedcam host pose (0050 T3).
 *
 * YNavi's [IAppHost.sendLocation] often stays silent until an active nav route;
 * [startLocationUpdates] SUCCESS alone is not enough. This source feeds the same
 * EventChannel (`zee/speedcam/location`) so harvest + HUD track the car without
 * needing a route.
 *
 * Prefer YNavi: when a YNavi fix arrived within [YNAVI_PREFER_MS], Android GPS
 * updates are dropped (no thrash). Call [noteYNaviFix] from the YNavi path.
 *
 * Runtime permission (0050 HARD): [start] no-ops without ACCESS_FINE/COARSE —
 * callers must [Activity.requestPermissions] first. [reemitLastKnown] after
 * grant / clearPose so Dart `fromLive` poses resume immediately.
 */
class AndroidGpsLocationSource(
    private val context: Context,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val onLocation: (Location) -> Unit,
) {
    companion object {
        private const val TAG = "ZEE"
        const val SOURCE = "android_gps"

        /** ~1 Hz — matches YNavi updateTrip cadence; fine enough for HUD radar. */
        private const val MIN_TIME_MS = 1_000L
        private const val MIN_DIST_M = 5f

        /** Suppress Android GPS while YNavi is delivering fresh fixes. */
        private const val YNAVI_PREFER_MS = 5_000L
    }

    private val locationManager: LocationManager? =
        context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    @Volatile private var listening = false
    @Volatile private var lastYNaviElapsedMs: Long = 0L
    @Volatile private var lastEmitted: Location? = null

    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            maybeEmit(location, fromLastKnown = false)
        }

        @Deprecated("Deprecated in API")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    /** Mark that YNavi just delivered a fix — Android GPS yields for a short window. */
    fun noteYNaviFix() {
        lastYNaviElapsedMs = SystemClock.elapsedRealtime()
    }

    fun hasFineOrCoarseLocation(): Boolean {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    fun start() {
        if (listening) return
        if (!hasFineOrCoarseLocation()) {
            Log.w(TAG, "AndroidGpsLocationSource: no ACCESS_FINE/COARSE_LOCATION — not starting")
            return
        }
        val lm = locationManager
        if (lm == null) {
            Log.w(TAG, "AndroidGpsLocationSource: LocationManager null")
            return
        }
        listening = true
        Log.i(TAG, "AndroidGpsLocationSource: start minTime=${MIN_TIME_MS}ms minDist=${MIN_DIST_M}m")

        // Immediate last-known so harvest/HUD aren't stuck until first fix.
        emitBestLastKnown(lm)

        @SuppressLint("MissingPermission")
        fun request(provider: String) {
            if (!lm.isProviderEnabled(provider)) {
                Log.i(TAG, "AndroidGpsLocationSource: provider=$provider disabled — skip")
                return
            }
            try {
                lm.requestLocationUpdates(provider, MIN_TIME_MS, MIN_DIST_M, listener, Looper.getMainLooper())
                Log.i(TAG, "AndroidGpsLocationSource: requestLocationUpdates provider=$provider")
            } catch (t: Throwable) {
                Log.e(TAG, "AndroidGpsLocationSource: requestLocationUpdates($provider) failed", t)
            }
        }

        request(LocationManager.GPS_PROVIDER)
        request(LocationManager.NETWORK_PROVIDER)
        // Passive catches fused/other apps' fixes without extra radio work.
        request(LocationManager.PASSIVE_PROVIDER)
    }

    fun stop() {
        if (!listening) return
        listening = false
        try {
            locationManager?.removeUpdates(listener)
        } catch (t: Throwable) {
            Log.w(TAG, "AndroidGpsLocationSource: removeUpdates failed", t)
        }
        Log.i(TAG, "AndroidGpsLocationSource: stop")
    }

    /**
     * Push last-known / cached fix again (after permission grant or clearPose).
     * Safe if not yet [start]ed — will emit lastKnown without registering updates
     * when permission is present; no-op when denied.
     */
    fun reemitLastKnown() {
        if (!hasFineOrCoarseLocation()) {
            Log.w(TAG, "AndroidGpsLocationSource: reemitLastKnown skipped — no permission")
            return
        }
        val cached = lastEmitted
        if (cached != null) {
            Log.i(
                TAG,
                "AndroidGpsLocationSource: reemit cached lat=${cached.latitude} lon=${cached.longitude}",
            )
            deliver(cached)
        }
        val lm = locationManager ?: return
        emitBestLastKnown(lm)
    }

    @SuppressLint("MissingPermission")
    private fun emitBestLastKnown(lm: LocationManager) {
        val candidates = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).mapNotNull { provider ->
            runCatching { lm.getLastKnownLocation(provider) }.getOrNull()
        }
        val best = candidates.maxByOrNull { it.time } ?: return
        maybeEmit(best, fromLastKnown = true)
    }

    private fun maybeEmit(location: Location, fromLastKnown: Boolean) {
        val sinceYNavi = SystemClock.elapsedRealtime() - lastYNaviElapsedMs
        if (lastYNaviElapsedMs > 0L && sinceYNavi < YNAVI_PREFER_MS) {
            Log.v(
                TAG,
                "AndroidGpsLocationSource: drop (YNavi preferred ${sinceYNavi}ms ago) " +
                    "lat=${location.latitude} lon=${location.longitude}",
            )
            return
        }
        lastEmitted = location
        deliver(location)
        if (fromLastKnown) {
            Log.i(
                TAG,
                "AndroidGpsLocationSource: lastKnown lat=${location.latitude} " +
                    "lon=${location.longitude} provider=${location.provider}",
            )
        }
    }

    private fun deliver(location: Location) {
        // Deliver on main — EventChannel must be touched on the platform thread.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            onLocation(location)
        } else {
            mainHandler.post { onLocation(location) }
        }
    }
}

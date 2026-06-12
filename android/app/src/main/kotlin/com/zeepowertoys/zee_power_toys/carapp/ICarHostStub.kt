package com.zeepowertoys.zee_power_toys.carapp

import android.annotation.SuppressLint
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.car.app.ICarHost
import androidx.car.app.constraints.IConstraintHost
import androidx.car.app.media.IMediaPlaybackHost
import androidx.car.app.navigation.INavigationHost
import androidx.car.app.serialization.Bundleable
import androidx.car.app.suggestion.ISuggestionHost

/**
 * ICarHost.Stub — multiplexes getHost() to sub-hosts.
 *
 * Lifted verbatim from phase0 ICarHostStub.kt, package renamed.
 * onTripUpdated / onNavigationStateChanged are the data-pipeline entry points
 * that YNaviCarAppHost wires to the guidance EventChannel.
 */
@SuppressLint("RestrictedApi")
class ICarHostStub(
    private val appHostStub: IAppHostStub,
    private val onFinishRequested: () -> Unit,
    private val loggerTag: String
) : ICarHost.Stub() {

    /** Called on binder thread when YNavi sends a trip update (~1 s interval). */
    @Volatile
    var onTripUpdated: ((androidx.car.app.navigation.model.Trip) -> Unit)? = null

    /** Called on binder thread when YNavi signals navigation started/ended. */
    @Volatile
    var onNavigationStateChanged: ((Boolean) -> Unit)? = null

    private val navigationHostStub = object : INavigationHost.Stub() {
        override fun navigationStarted() {
            Log.i(loggerTag, "INavigationHost.navigationStarted")
            onNavigationStateChanged?.invoke(true)
        }

        override fun navigationEnded() {
            Log.i(loggerTag, "INavigationHost.navigationEnded")
            onNavigationStateChanged?.invoke(false)
        }

        override fun updateTrip(trip: Bundleable?) {
            val parsed = try {
                trip?.get() as? androidx.car.app.navigation.model.Trip
            } catch (e: Exception) {
                Log.w(loggerTag, "INavigationHost.updateTrip unpack failed", e)
                null
            }
            if (parsed != null) {
                Log.i(loggerTag, "INavigationHost.updateTrip steps=${parsed.steps.size} dest=${parsed.destinations.size} road=${parsed.currentRoad}")
                onTripUpdated?.invoke(parsed)
            } else {
                Log.i(loggerTag, "INavigationHost.updateTrip payload=${extractBundleablePayload(trip)}")
            }
        }
    }

    private val constraintHostStub = object : IConstraintHost.Stub() {
        override fun getContentLimit(contentLimitType: Int): Int = 100
        override fun isAppDrivenRefreshEnabled(): Boolean = true
    }

    private val suggestionHostStub = object : ISuggestionHost.Stub() {
        override fun updateSuggestions(suggestions: Bundleable?) {
            Log.v(loggerTag, "ISuggestionHost.updateSuggestions")
        }
    }

    private val mediaPlaybackHostStub = object : IMediaPlaybackHost.Stub() {
        override fun registerMediaSessionToken(token: Bundleable?) {
            Log.v(loggerTag, "IMediaPlaybackHost.registerMediaSessionToken")
        }
    }

    override fun startCarApp(intent: Intent?) {
        Log.i(loggerTag, "ICarHost.startCarApp intent=$intent")
    }

    override fun getHost(type: String?): IBinder? {
        val value = type.orEmpty()
        Log.i(loggerTag, "ICarHost.getHost type=$value")
        return when (value) {
            "app" -> appHostStub.asBinder()
            "navigation" -> navigationHostStub.asBinder()
            "constraints" -> constraintHostStub.asBinder()
            "suggestion" -> suggestionHostStub.asBinder()
            "media_playback" -> mediaPlaybackHostStub.asBinder()
            else -> null
        }
    }

    override fun finish() {
        Log.i(loggerTag, "ICarHost.finish")
        onFinishRequested()
    }

    private fun extractBundleablePayload(bundleable: Bundleable?): String {
        if (bundleable == null) return "null"
        return runCatching { bundleable.get()?.toString() ?: "null_payload" }
            .getOrElse { e -> "<unpack-failed ${e.javaClass.simpleName}: ${e.message}>" }
    }
}

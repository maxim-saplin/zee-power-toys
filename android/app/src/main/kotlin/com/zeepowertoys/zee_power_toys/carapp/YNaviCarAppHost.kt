package com.zeepowertoys.zee_power_toys.carapp

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.res.Configuration
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.RemoteException
import android.util.Log
import android.view.Surface
import androidx.car.app.CarAppService
import androidx.car.app.HandshakeInfo
import androidx.car.app.IAppManager
import androidx.car.app.ICarApp
import androidx.car.app.IOnDoneCallback
import androidx.car.app.SessionInfo
import androidx.car.app.SessionInfoIntentEncoder
import androidx.car.app.SurfaceContainer
import androidx.car.app.navigation.model.Trip
import androidx.car.app.serialization.Bundleable
import androidx.car.app.versioning.CarAppApiLevels
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * YNaviCarAppHost — plain controller class (no Service) owned by MainActivity.
 *
 * Ports the load-bearing CarApp host logic from phase0's CarAppHostService:
 *   - ServiceConnection (onServiceConnected / onServiceDisconnected / onBindingDied)
 *   - performHandshake: onHandshakeCompleted → onAppCreate(DISPLAY_TYPE_CLUSTER) → onAppStart → onAppResume
 *   - callWithTimeout / callForResultWithTimeout (10 s IOnDoneCallback)
 *   - fetchAppManager + startLocationUpdates
 *   - stopHosting: ordered onAppPause → onAppStop → unbind
 *   - attemptReconnect after 5 s on disconnect/binding-death
 *
 * Differs from phase0: NO HudPresentation / VirtualDisplay / GuidanceOverlay / BlinkerOverlay.
 * The Surface comes from the existing MinimapView TextureView in MainActivity.
 *
 * API:
 *   start(surface, width, height, dpi) — bind YNavi + perform handshake; when YNavi calls
 *       setSurfaceCallback the SurfaceContainer(surface,w,h,dpi) is dispatched back to YNavi.
 *   stop()                             — ordered teardown.
 *   onTrip: ((Trip)->Unit)?            — fired on main thread each trip update (~1 s).
 *   onNavState: ((Boolean)->Unit)?     — fired on main thread when navigation starts/ends.
 */
@SuppressLint("RestrictedApi")
class YNaviCarAppHost(
    private val context: Context,
    private val mainHandler: Handler = Handler(Looper.getMainLooper())
) {

    // -------------------------------------------------------------------------
    // Public callbacks — wired by MainActivity to forward to the EventChannel.
    // -------------------------------------------------------------------------

    /** Called on the main thread with each trip update from YNavi (~1 s interval). */
    var onTrip: ((Trip) -> Unit)? = null

    /** Called on the main thread when navigation starts (true) or ends (false). */
    var onNavState: ((Boolean) -> Unit)? = null

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------

    private val worker = Executors.newSingleThreadExecutor()
    private val appHostStub = IAppHostStub(mainHandler, TAG)
    private val carHostStub = ICarHostStub(
        appHostStub = appHostStub,
        onFinishRequested = { mainHandler.post { stop() } },
        loggerTag = TAG
    )

    @Volatile private var carApp: ICarApp? = null
    @Volatile private var appManager: IAppManager? = null
    @Volatile private var isBound = false
    @Volatile private var active = false  // true when start() has been called, false after stop()

    /** True between start() and stop() — read by MainActivity to avoid restarting a live host. */
    val isActive: Boolean get() = active

    // Session epoch. Bumped on every start(); a delayed unbind scheduled by an
    // earlier stop() is abandoned if the epoch advanced (an intervening start()
    // opened a newer session whose fresh binding must not be torn down). See stop().
    private val sessionEpoch = AtomicInteger(0)

    private val reconnectRunnable = Runnable { attemptReconnect() }

    // -------------------------------------------------------------------------
    // ServiceConnection
    // -------------------------------------------------------------------------

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            Log.i(TAG, "onServiceConnected name=${name.flattenToShortString()}")
            mainHandler.removeCallbacks(reconnectRunnable)
            carApp = ICarApp.Stub.asInterface(service)
            worker.execute { performHandshake(carApp ?: return@execute) }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            Log.w(TAG, "onServiceDisconnected name=${name.flattenToShortString()}")
            carApp = null
            appHostStub.clearSurfaceCallback()
            if (active) {
                Log.i(TAG, "Scheduling reconnect in ${RECONNECT_DELAY_MS}ms")
                mainHandler.removeCallbacks(reconnectRunnable)
                mainHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
            }
        }

        override fun onBindingDied(name: ComponentName) {
            Log.w(TAG, "onBindingDied name=${name.flattenToShortString()}")
            carApp = null
            appHostStub.clearSurfaceCallback()
            try {
                if (isBound) {
                    context.unbindService(this)
                    isBound = false
                    Log.i(TAG, "Unbound dead binding")
                }
            } catch (e: Throwable) {
                Log.w(TAG, "unbindService in onBindingDied failed", e)
                isBound = false
            }
            if (active) {
                Log.i(TAG, "Scheduling rebind in ${RECONNECT_DELAY_MS}ms after binding death")
                mainHandler.removeCallbacks(reconnectRunnable)
                mainHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /**
     * Bind YNavi and perform the CarApp handshake. When YNavi calls setSurfaceCallback
     * the SurfaceContainer built from [surface] is dispatched so it renders the cluster.
     *
     * Must be called on the main thread (or any thread is fine — Context.bindService is
     * thread-safe, appHostStub is volatile-safe).
     */
    fun start(surface: Surface, width: Int, height: Int, dpi: Int) {
        Log.i(TAG, "start w=$width h=$height dpi=$dpi surface.isValid=${surface.isValid}")
        active = true
        // Open a new session epoch. Any delayed unbind still pending from a recent
        // stop() now sees a stale epoch and abandons its teardown, so it cannot tear
        // down this fresh binding (the stop→start race). See performStop().
        val epoch = sessionEpoch.incrementAndGet()
        Log.i(TAG, "start: session epoch=$epoch")
        mainHandler.removeCallbacks(reconnectRunnable)
        // Provide the surface to IAppHostStub; YNavi will pick it up when it calls
        // setSurfaceCallback (or the container is dispatched immediately if the callback
        // was already set — unlikely on cold start).
        appHostStub.onSurfaceReady(SurfaceContainer(surface, width, height, dpi))
        // If a recent stop() left the binding live (its delayed unbind is now abandoned
        // by the epoch bump above), the connection won't fire onServiceConnected again —
        // re-run the handshake on the surviving binding so the new session has a live
        // carApp. A cold start (no live carApp) goes through the normal bind path.
        val live = carApp
        if (isBound && live != null) {
            Log.i(TAG, "start: reusing live binding — re-running handshake")
            worker.execute { performHandshake(live) }
        } else {
            bindToNavigationCarApp()
        }
    }

    /**
     * Ordered teardown: onAppPause → onAppStop → unbind.
     * The 2 s REBIND_DELAY_MS wait before unbind lets YNavi's onDestroyLifecycle run
     * so the next onAppCreate sees ON_CREATE not a stale lifecycle.
     */
    fun stop() {
        Log.i(TAG, "stop")
        active = false
        mainHandler.removeCallbacks(reconnectRunnable)
        // Capture the epoch this stop belongs to. The delayed unbind only fires if the
        // epoch is unchanged when the REBIND_DELAY_MS wait elapses; a start() in that
        // window bumps the epoch and the unbind is abandoned, preserving the new binding.
        performStop(epoch = sessionEpoch.get(), onComplete = null)
    }

    /**
     * Notify the host that the MinimapView surface geometry changed (e.g. bounds updated).
     * Re-dispatches the SurfaceContainer with updated dimensions if already connected.
     */
    fun updateSurface(surface: Surface, width: Int, height: Int, dpi: Int) {
        Log.i(TAG, "updateSurface w=$width h=$height dpi=$dpi")
        appHostStub.onSurfaceReady(SurfaceContainer(surface, width, height, dpi))
    }

    // -------------------------------------------------------------------------
    // Bind
    // -------------------------------------------------------------------------

    private fun bindToNavigationCarApp() {
        if (isBound) {
            Log.i(TAG, "bindToNavigationCarApp: already bound — skipping")
            return
        }
        val bindIntent = Intent(CarAppService.SERVICE_INTERFACE).setComponent(
            ComponentName(TARGET_PACKAGE, TARGET_SERVICE)
        )
        isBound = try {
            context.bindService(bindIntent, connection, Context.BIND_AUTO_CREATE)
        } catch (e: Throwable) {
            Log.e(TAG, "bindService failed", e)
            false
        }
        Log.i(TAG, "bindService result=$isBound")
    }

    // -------------------------------------------------------------------------
    // Handshake (verbatim from phase0 performHandshake, night-mode skipped for MVP)
    // -------------------------------------------------------------------------

    private fun performHandshake(target: ICarApp) {
        // Wire callbacks so trip data flows to the EventChannel.
        carHostStub.onTripUpdated = { trip ->
            mainHandler.post { onTrip?.invoke(trip) }
        }
        carHostStub.onNavigationStateChanged = { active ->
            mainHandler.post { onNavState?.invoke(active) }
        }

        if (!callWithTimeout("onHandshakeCompleted") { cb ->
                val info = HandshakeInfo(context.packageName, CarAppApiLevels.LEVEL_1)
                target.onHandshakeCompleted(Bundleable.create(info), cb)
            }) return

        val appIntent = Intent(CarAppService.SERVICE_INTERFACE).setComponent(
            ComponentName(TARGET_PACKAGE, TARGET_SERVICE)
        )
        SessionInfoIntentEncoder.encode(
            SessionInfo(SessionInfo.DISPLAY_TYPE_CLUSTER, "zee-cluster-${System.currentTimeMillis()}"),
            appIntent
        )

        if (!callWithTimeout("onAppCreate") { cb ->
                target.onAppCreate(carHostStub, appIntent, context.resources.configuration, cb)
            }) return

        if (!callWithTimeout("onAppStart") { cb -> target.onAppStart(cb) }) return

        if (!callWithTimeout("onAppResume") { cb -> target.onAppResume(cb) }) return

        // Fetch AppManager and start location updates (same as phase0 probeManagersAndTemplates).
        fetchAppManagerAndStartUpdates(target)
    }

    private fun fetchAppManagerAndStartUpdates(target: ICarApp) {
        val result = callForResultWithTimeout("getManager(app)") { cb ->
            target.getManager("app", cb)
        } ?: return

        val unpacked = runCatching { result.get() }.getOrElse { e ->
            Log.e(TAG, "getManager(app) unpack failed", e)
            null
        } ?: return

        val manager: IAppManager? = when (unpacked) {
            is IAppManager -> unpacked
            is IBinder -> IAppManager.Stub.asInterface(unpacked)
            else -> null
        }
        Log.i(TAG, "getManager(app) resolved=${manager != null} type=${unpacked.javaClass.name}")
        appManager = manager

        if (manager != null) {
            callWithTimeout("startLocationUpdates") { cb ->
                manager.startLocationUpdates(cb)
            }
            appHostStub.onInvalidate = {
                // No-op on this path — we don't probe templates; guidance comes via updateTrip.
            }
        }
    }

    // -------------------------------------------------------------------------
    // Teardown (verbatim from phase0 stopHosting, minus Presentation handling)
    // -------------------------------------------------------------------------

    private fun performStop(epoch: Int, onComplete: (() -> Unit)?) {
        val target = carApp

        worker.execute {
            if (target != null) {
                callWithTimeout("onAppPause") { cb -> target.onAppPause(cb) }
                callWithTimeout("onAppStop") { cb -> target.onAppStop(cb) }
            }

            // Wait for YNavi's onDestroyLifecycle to complete before unbinding.
            try { Thread.sleep(REBIND_DELAY_MS) } catch (_: InterruptedException) {}

            // Abandon teardown if a start() opened a newer session during the wait —
            // its fresh binding must survive. Without this guard the stale unbind
            // kills the live bind ("unbindService completed" on a healthy session).
            if (sessionEpoch.get() != epoch) {
                Log.i(TAG, "performStop(epoch=$epoch): superseded by epoch ${sessionEpoch.get()} — skipping unbind")
                mainHandler.post { onComplete?.invoke() }
                return@execute
            }

            // Commit teardown: drop the session state and unbind.
            carApp = null
            appManager = null
            appHostStub.onInvalidate = null
            carHostStub.onTripUpdated = null
            carHostStub.onNavigationStateChanged = null

            val latch = CountDownLatch(1)
            mainHandler.post {
                // Re-check on the main thread: a start() may have raced in after the
                // worker-thread epoch check but before this runnable executes.
                if (sessionEpoch.get() != epoch) {
                    Log.i(TAG, "performStop(epoch=$epoch): superseded on main — skipping unbind")
                    latch.countDown()
                    return@post
                }
                try {
                    if (isBound) {
                        context.unbindService(connection)
                        isBound = false
                        Log.i(TAG, "unbindService completed")
                    }
                } catch (e: Throwable) {
                    Log.w(TAG, "unbindService failed", e)
                    isBound = false
                }
                latch.countDown()
            }
            latch.await(3, TimeUnit.SECONDS)
            if (sessionEpoch.get() == epoch) appHostStub.clearSurfaceCallback()
            mainHandler.post { onComplete?.invoke() }
        }
    }

    // -------------------------------------------------------------------------
    // Reconnect
    // -------------------------------------------------------------------------

    private fun attemptReconnect() {
        if (!active) return
        Log.i(TAG, "attemptReconnect isBound=$isBound")
        if (isBound) {
            try { context.unbindService(connection) } catch (_: Throwable) {}
            isBound = false
        }
        bindToNavigationCarApp()
    }

    // -------------------------------------------------------------------------
    // IOnDoneCallback helpers (verbatim from phase0)
    // -------------------------------------------------------------------------

    private fun callWithTimeout(step: String, remoteCall: (IOnDoneCallback) -> Unit): Boolean {
        val latch = CountDownLatch(1)
        val errorRef = AtomicReference<String?>(null)
        val callback = object : IOnDoneCallback.Stub() {
            override fun onSuccess(response: Bundleable?) {
                Log.i(TAG, "$step SUCCESS")
                latch.countDown()
            }
            override fun onFailure(failureResponse: Bundleable?) {
                val msg = runCatching { failureResponse?.get()?.toString() }.getOrNull() ?: "?"
                Log.e(TAG, "$step FAILURE payload=$msg")
                errorRef.set(msg)
                latch.countDown()
            }
        }
        return try {
            remoteCall(callback)
            val completed = latch.await(CALL_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            when {
                !completed -> { Log.e(TAG, "$step TIMEOUT after ${CALL_TIMEOUT_MS}ms"); false }
                errorRef.get() != null -> false
                else -> true
            }
        } catch (e: RemoteException) {
            Log.e(TAG, "$step RemoteException", e)
            false
        } catch (e: Throwable) {
            Log.e(TAG, "$step failed", e)
            false
        }
    }

    private fun callForResultWithTimeout(step: String, remoteCall: (IOnDoneCallback) -> Unit): Bundleable? {
        val latch = CountDownLatch(1)
        val resultRef = AtomicReference<Bundleable?>(null)
        val errorRef = AtomicReference<String?>(null)
        val callback = object : IOnDoneCallback.Stub() {
            override fun onSuccess(response: Bundleable?) {
                resultRef.set(response)
                Log.i(TAG, "$step SUCCESS")
                latch.countDown()
            }
            override fun onFailure(failureResponse: Bundleable?) {
                val msg = runCatching { failureResponse?.get()?.toString() }.getOrNull() ?: "?"
                Log.e(TAG, "$step FAILURE payload=$msg")
                errorRef.set(msg)
                latch.countDown()
            }
        }
        return try {
            remoteCall(callback)
            val completed = latch.await(CALL_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            when {
                !completed -> { Log.e(TAG, "$step TIMEOUT after ${CALL_TIMEOUT_MS}ms"); null }
                errorRef.get() != null -> null
                else -> resultRef.get()
            }
        } catch (e: RemoteException) {
            Log.e(TAG, "$step RemoteException", e)
            null
        } catch (e: Throwable) {
            Log.e(TAG, "$step failed", e)
            null
        }
    }

    companion object {
        private const val TAG = "ZEE/YNaviCarApp"
        const val TARGET_PACKAGE = "ru.yandex.yandexnavi"
        const val TARGET_SERVICE =
            "ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService"

        /** Timeout per IOnDoneCallback call (phase0 production value). */
        private const val CALL_TIMEOUT_MS = 10_000L

        /** Wait after unbind for YNavi's onDestroyLifecycle (phase0 production value). */
        private const val REBIND_DELAY_MS = 2_000L

        /** Reconnect delay after onServiceDisconnected / onBindingDied (phase0 production value). */
        private const val RECONNECT_DELAY_MS = 5_000L
    }
}

package com.zeepowertoys.zee_power_toys.carapp

import android.annotation.SuppressLint
import android.graphics.Rect
import android.location.Location
import android.os.Handler
import android.os.RemoteException
import android.util.Log
import androidx.car.app.FailureResponse
import androidx.car.app.IAppHost
import androidx.car.app.IOnDoneCallback
import androidx.car.app.ISurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.serialization.Bundleable
import androidx.car.app.serialization.BundlerException
import kotlin.math.roundToInt

/**
 * IAppHost.Stub — host-side surface + viewport implementation.
 *
 * Lifted verbatim from phase0 IAppHostStub.kt, package renamed.
 * Stores the ISurfaceCallback YNavi sends, holds the SurfaceContainer,
 * and dispatches onSurfaceAvailable / onVisibleAreaChanged / onStableAreaChanged.
 * computeViewportRect() preserves HUD safe-area constants from on-car calibration.
 */
@SuppressLint("RestrictedApi")
class IAppHostStub(
    private val mainHandler: Handler,
    private val loggerTag: String
) : IAppHost.Stub() {

    enum class MinimapViewportMode(val wireValue: String) {
        FULL_SCREEN("full_screen"),
        SQUARE_LEFT("square_left"),
        SQUARE_RIGHT("square_right");

        companion object {
            fun fromWireValue(value: String?): MinimapViewportMode =
                entries.firstOrNull { it.wireValue == value } ?: FULL_SCREEN
        }
    }

    @Volatile private var surfaceCallback: ISurfaceCallback? = null
    @Volatile private var currentSurfaceContainer: SurfaceContainer? = null
    @Volatile var onInvalidate: (() -> Unit)? = null
    /** Fired on the binder thread when YNavi pushes a location update. */
    @Volatile var onLocation: ((Location) -> Unit)? = null
    @Volatile private var minimapViewportMode: MinimapViewportMode = MinimapViewportMode.FULL_SCREEN
    @Volatile private var squareSizeFraction: Float = DEFAULT_SQUARE_HEIGHT_FRACTION
    @Volatile private var squarePaddingDp: Float = DEFAULT_SQUARE_EDGE_PADDING_DP

    override fun invalidate() {
        Log.i(loggerTag, "IAppHost.invalidate")
        onInvalidate?.invoke()
    }

    override fun showToast(text: CharSequence?, duration: Int) {
        Log.i(loggerTag, "IAppHost.showToast text=$text duration=$duration")
    }

    override fun setSurfaceCallback(callback: ISurfaceCallback?) {
        Log.i(loggerTag, "IAppHost.setSurfaceCallback callback=${callback != null}")
        surfaceCallback = callback
        dispatchSurfaceAvailableIfPossible()
    }

    override fun sendLocation(location: Location?) {
        // Log.i (not v) — T3 triage: YNavi often never calls this without an
        // active nav route even after startLocationUpdates SUCCESS (0050 FAIL).
        // Also log under TAG "ZEE" so `adb logcat -s ZEE` catches it (loggerTag
        // is typically "ZEE/YNaviCarApp", which -s ZEE does not match).
        if (location == null) {
            Log.i(loggerTag, "IAppHost.sendLocation location=null onLocationWired=${onLocation != null}")
            Log.i("ZEE", "IAppHost.sendLocation location=null onLocationWired=${onLocation != null}")
            return
        }
        val msg =
            "IAppHost.sendLocation lat=${location.latitude} lon=${location.longitude} " +
                "hasSpeed=${location.hasSpeed()} hasBearing=${location.hasBearing()} " +
                "onLocationWired=${onLocation != null}"
        Log.i(loggerTag, msg)
        Log.i("ZEE", msg)
        onLocation?.invoke(location)
    }

    override fun showAlert(alert: Bundleable?) {
        Log.i(loggerTag, "IAppHost.showAlert")
    }

    override fun dismissAlert(alertId: Int) {
        Log.i(loggerTag, "IAppHost.dismissAlert alertId=$alertId")
    }

    override fun openMicrophone(request: Bundleable?): Bundleable {
        return try {
            Bundleable.create(FailureResponse(UnsupportedOperationException("openMicrophone unsupported")))
        } catch (error: BundlerException) {
            throw RemoteException(error.message)
        }
    }

    fun onSurfaceReady(container: SurfaceContainer) {
        currentSurfaceContainer = container
        dispatchSurfaceAvailableIfPossible()
    }

    fun clearSurfaceCallback() {
        Log.i(loggerTag, "IAppHost.clearSurfaceCallback (session reset)")
        surfaceCallback = null
    }

    fun setMinimapViewportMode(mode: MinimapViewportMode, dispatchIfSurfaceReady: Boolean = true) {
        minimapViewportMode = mode
        if (dispatchIfSurfaceReady) dispatchVisibleAreaIfPossible("modeChange")
    }

    fun setSquareGeometry(sizeFraction: Float, paddingDp: Float) {
        squareSizeFraction = sizeFraction.coerceIn(0.3f, 1.0f)
        squarePaddingDp = paddingDp.coerceIn(0f, 100f)
    }

    fun hasSurfaceCallback(): Boolean = surfaceCallback != null

    fun onSurfaceDestroyed() {
        val callback = surfaceCallback ?: return
        val container = currentSurfaceContainer ?: return
        mainHandler.post {
            runCatching {
                callback.onSurfaceDestroyed(
                    Bundleable.create(container),
                    LoggingOnDoneCallback(loggerTag, "onSurfaceDestroyed")
                )
            }.onFailure { error -> Log.e(loggerTag, "onSurfaceDestroyed failed", error) }
        }
    }

    private fun dispatchSurfaceAvailableIfPossible() {
        val callback = surfaceCallback ?: return
        val container = currentSurfaceContainer ?: return
        mainHandler.post {
            runCatching {
                callback.onSurfaceAvailable(
                    Bundleable.create(container),
                    LoggingOnDoneCallback(loggerTag, "onSurfaceAvailable")
                )
                dispatchVisibleArea(callback, container, "initial")
            }.onFailure { error -> Log.e(loggerTag, "Surface dispatch failed", error) }
        }
    }

    private fun dispatchVisibleAreaIfPossible(reason: String) {
        val callback = surfaceCallback ?: return
        val container = currentSurfaceContainer ?: return
        mainHandler.post {
            runCatching {
                dispatchVisibleArea(callback, container, reason)
            }.onFailure { error -> Log.e(loggerTag, "Visible area update failed", error) }
        }
    }

    private fun dispatchVisibleArea(callback: ISurfaceCallback, container: SurfaceContainer, reason: String) {
        val visible = Rect(0, 0, container.width, container.height)
        Log.i(loggerTag, "onVisibleAreaChanged[$reason] mode=${minimapViewportMode.wireValue} surface=${container.width}x${container.height}")
        callback.onVisibleAreaChanged(visible, LoggingOnDoneCallback(loggerTag, "onVisibleAreaChanged[$reason]"))
        callback.onStableAreaChanged(visible, LoggingOnDoneCallback(loggerTag, "onStableAreaChanged[$reason]"))
    }

    private class LoggingOnDoneCallback(
        private val tag: String,
        private val step: String
    ) : IOnDoneCallback.Stub() {
        override fun onSuccess(response: Bundleable?) {
            Log.i(tag, "$step SUCCESS")
        }
        override fun onFailure(failureResponse: Bundleable?) {
            val payload = runCatching { failureResponse?.get()?.toString() ?: "null" }
                .getOrElse { e -> "<unpack-failed ${e.javaClass.simpleName}: ${e.message}>" }
            Log.e(tag, "$step FAILURE payload=$payload")
        }
    }

    companion object {
        private const val DEFAULT_SQUARE_EDGE_PADDING_DP = 31f
        private const val DEFAULT_SQUARE_HEIGHT_FRACTION = 0.9f
        private const val FALLBACK_DPI = 160

        // HUD optical safe area — on-car calibration (616dp × 175dp, centre offset +5dp/+6dp).
        private const val SAFE_AREA_WIDTH_DP = 616f
        private const val SAFE_AREA_HEIGHT_DP = 175f
        private const val SAFE_AREA_OFFSET_X_DP = 5f
        private const val SAFE_AREA_OFFSET_Y_DP = 6f

        fun computeViewportRect(
            displayWidth: Int,
            displayHeight: Int,
            dpi: Int,
            mode: MinimapViewportMode,
            sizeFraction: Float = DEFAULT_SQUARE_HEIGHT_FRACTION,
            paddingDp: Float = DEFAULT_SQUARE_EDGE_PADDING_DP
        ): Rect {
            val fullSurface = Rect(0, 0, displayWidth, displayHeight)
            if (mode == MinimapViewportMode.FULL_SCREEN) return fullSurface

            val densityDpi = if (dpi > 0) dpi else FALLBACK_DPI
            val density = densityDpi / 160f
            val paddingPx = (paddingDp * density).roundToInt()

            val safeCenterX = displayWidth / 2 + (SAFE_AREA_OFFSET_X_DP * density).roundToInt()
            val safeCenterY = displayHeight / 2 + (SAFE_AREA_OFFSET_Y_DP * density).roundToInt()
            val safeW = (SAFE_AREA_WIDTH_DP * density).roundToInt().coerceAtMost(displayWidth)
            val safeH = (SAFE_AREA_HEIGHT_DP * density).roundToInt().coerceAtMost(displayHeight)
            val safeLeft = (safeCenterX - safeW / 2).coerceAtLeast(0)
            val safeRight = (safeLeft + safeW).coerceAtMost(displayWidth)

            val side = (safeH * sizeFraction).roundToInt()
                .coerceAtMost(safeW - 2 * paddingPx)
                .coerceAtLeast(1)
            val top = safeCenterY - side / 2

            val left = when (mode) {
                MinimapViewportMode.SQUARE_LEFT -> safeLeft + paddingPx
                MinimapViewportMode.SQUARE_RIGHT -> safeRight - side - paddingPx
                else -> 0
            }
            return clampRect(Rect(left, top, left + side, top + side), fullSurface)
        }

        private fun clampRect(rect: Rect, bounds: Rect): Rect {
            val w = rect.width().coerceAtMost(bounds.width()).coerceAtLeast(1)
            val h = rect.height().coerceAtMost(bounds.height()).coerceAtLeast(1)
            val l = rect.left.coerceIn(bounds.left, (bounds.right - w).coerceAtLeast(bounds.left))
            val t = rect.top.coerceIn(bounds.top, (bounds.bottom - h).coerceAtLeast(bounds.top))
            return Rect(l, t, l + w, t + h)
        }
    }
}

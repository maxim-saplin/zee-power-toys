package com.zeepowertoys.zee_power_toys.speedcam

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 0070 — DHU Speedcam system overlay hosts the same Flutter Speedcam radar
 * (Alien|Default) in a TYPE_APPLICATION_OVERLAY window.
 *
 * Channel [CHANNEL]: canDrawOverlays / openPermissionSettings / setEnabled /
 * update({visible, …}) / hide.
 *
 * Visibility (approach/demo) is still gated by Dart via [update]; the Flutter
 * surface reuses [SpeedcamRadarWidget] via entrypoint `speedcamOverlayEntry`
 * and receives config/snapshot over zee/hub (fan-out from MainActivity).
 */
class SpeedcamSystemOverlayController(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "ZEE/SpeedcamOverlay"
        const val CHANNEL = "zee/speedcam/system_overlay"
        private const val HUB_CHANNEL = "zee/hub"
        /** Overlay disk size (dp) — matches DHU settings preview ballpark. */
        /** Longer side (width) of landscape CRT plate; height = width / ASPECT. */
        private const val OVERLAY_WIDTH_DP = 280
        /** 300∶220 landscape — must match Dart [kSpeedcamCrtPlateAspect]. */
        private const val OVERLAY_ASPECT = 300.0 / 220.0
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val appContext = context.applicationContext
    private val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var enabled = false
    private var contentVisible = false
    private var sizeScale = 1.0
    private var placement = "topEnd"

    private var engineGroup: FlutterEngineGroup? = null
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var root: FrameLayout? = null
    private var overlayHub: MethodChannel? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(canDrawOverlays())
                "openPermissionSettings" -> {
                    openPermissionSettings()
                    result.success(null)
                }
                "setEnabled" -> {
                    val on = call.argument<Boolean>("enabled") ?: false
                    mainHandler.post {
                        enabled = on
                        if (!on) {
                            contentVisible = false
                            tearDownEngineAndWindow()
                        } else if (canDrawOverlays()) {
                            ensureEngine()
                            // Window stays GONE until update(visible=true).
                            ensureWindow(shown = false)
                        }
                        result.success(null)
                    }
                }
                "update" -> {
                    val visible = call.argument<Boolean>("visible") ?: true
                    mainHandler.post {
                        if (!enabled || !canDrawOverlays()) {
                            contentVisible = false
                            hideWindowOnly()
                            Log.i(TAG, "update visible=$visible ignored (enabled=$enabled)")
                            result.success(null)
                            return@post
                        }
                        contentVisible = visible
                        if (!visible) {
                            hideWindowOnly()
                            Log.i(TAG, "update visible=false → GONE")
                            result.success(null)
                            return@post
                        }
                        ensureEngine()
                        ensureWindow(shown = true)
                        // GONE→VISIBLE on TYPE_APPLICATION_OVERLAY can leave
                        // Requested 0×0 / no surface until an explicit relayout.
                        forceOverlaySurface()
                        Log.i(TAG, "update visible=true → VISIBLE")
                        result.success(null)
                    }
                }
                "hide" -> {
                    mainHandler.post {
                        contentVisible = false
                        hideWindowOnly()
                        result.success(null)
                    }
                }
                "setLayout" -> {
                    val scale = (call.argument<Number>("sizeScale") ?: 1.0).toDouble()
                        .coerceIn(0.6, 1.6)
                    val place = call.argument<String>("placement") ?: "topEnd"
                    mainHandler.post {
                        sizeScale = scale
                        placement = place
                        applyLayoutToWindow()
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        Log.i(TAG, "SpeedcamSystemOverlayController registered (0070 Flutter surface)")
    }

    /** Fan-out from MainActivity DHU hub → overlay isolate (same envelopes as HUD). */
    fun onRelayFromDhu(arguments: Any?) {
        overlayHub?.invokeMethod("relay", arguments)
    }

    fun dispose() {
        mainHandler.post { tearDownEngineAndWindow() }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(appContext)
        } else {
            true
        }
    }

    private fun openPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${appContext.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun ensureEngine() {
        if (engine != null) return
        try {
            val group = engineGroup ?: FlutterEngineGroup(appContext).also { engineGroup = it }
            val entry = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "speedcamOverlayEntry",
            )
            val eng = group.createAndRunEngine(appContext, entry)
            eng.lifecycleChannel.appIsResumed()
            engine = eng
            overlayHub = MethodChannel(eng.dartExecutor.binaryMessenger, HUB_CHANNEL)
            Log.i(TAG, "overlay FlutterEngine created = $eng")
        } catch (t: Throwable) {
            Log.e(TAG, "ensureEngine failed", t)
            engine = null
            overlayHub = null
        }
    }

    private fun ensureWindow(shown: Boolean) {
        val eng = engine ?: return
        if (root == null) {
            if (!canDrawOverlays()) {
                Log.w(TAG, "ensureWindow: SYSTEM_ALERT_WINDOW not granted")
                return
            }
            val density = appContext.resources.displayMetrics.density
            val widthPx = overlayWidthPx(density)
            val heightPx = overlayHeightPx(widthPx)

            val container = FrameLayout(appContext).apply {
                setBackgroundColor(Color.TRANSPARENT)
            }

            val ftv = FlutterTextureView(appContext)
            ftv.isOpaque = false
            val fv = FlutterView(appContext, ftv)
            container.addView(
                fv,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val lp = WindowManager.LayoutParams(
                widthPx,
                heightPx,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply {
                applyPlacement(this, density)
            }
            try {
                wm.addView(container, lp)
                fv.attachToFlutterEngine(eng)
                root = container
                flutterView = fv
                Log.i(TAG, "overlay FlutterView window added ${widthPx}x${heightPx}px (landscape CRT)")
            } catch (e: Exception) {
                Log.e(TAG, "addView failed", e)
                try {
                    fv.detachFromFlutterEngine()
                } catch (_: Exception) {
                }
                root = null
                flutterView = null
                return
            }
        }
        root?.visibility = if (shown) View.VISIBLE else View.GONE
    }

    private fun hideWindowOnly() {
        root?.visibility = View.GONE
    }

    private fun tearDownEngineAndWindow() {
        val v = root
        val fv = flutterView
        root = null
        flutterView = null
        if (v != null) {
            try {
                fv?.detachFromFlutterEngine()
            } catch (e: Exception) {
                Log.w(TAG, "detach: ${e.message}")
            }
            try {
                wm.removeView(v)
                Log.i(TAG, "overlay window removed")
            } catch (e: Exception) {
                Log.w(TAG, "removeView: ${e.message}")
            }
        }
        overlayHub = null
        val eng = engine
        engine = null
        if (eng != null) {
            try {
                eng.destroy()
                Log.i(TAG, "overlay FlutterEngine destroyed")
            } catch (e: Exception) {
                Log.w(TAG, "engine.destroy: ${e.message}")
            }
        }
        engineGroup = null
    }
    private fun applyPlacement(lp: WindowManager.LayoutParams, density: Float) {
        val marginX = (16 * density).toInt()
        val marginY = (72 * density).toInt()
        when (placement) {
            "topStart" -> {
                lp.gravity = Gravity.TOP or Gravity.START
                lp.x = marginX
                lp.y = marginY
            }
            "bottomStart" -> {
                lp.gravity = Gravity.BOTTOM or Gravity.START
                lp.x = marginX
                lp.y = marginY
            }
            "bottomEnd" -> {
                lp.gravity = Gravity.BOTTOM or Gravity.END
                lp.x = marginX
                lp.y = marginY
            }
            else -> {
                lp.gravity = Gravity.TOP or Gravity.END
                lp.x = marginX
                lp.y = marginY
            }
        }
    }


    private fun overlayWidthPx(density: Float): Int =
        (OVERLAY_WIDTH_DP * sizeScale * density).toInt().coerceAtLeast(1)

    private fun overlayHeightPx(widthPx: Int): Int =
        (widthPx / OVERLAY_ASPECT).toInt().coerceAtLeast(1)


    /** After GONE→VISIBLE, push lp so WM allocates a surface (non-zero Requested). */
    private fun forceOverlaySurface() {
        val container = root ?: return
        val lp = container.layoutParams as? WindowManager.LayoutParams ?: return
        val density = appContext.resources.displayMetrics.density
        if (lp.width <= 0 || lp.height <= 0) {
            lp.width = overlayWidthPx(density)
            lp.height = overlayHeightPx(lp.width)
            applyPlacement(lp, density)
        }
        try {
            wm.updateViewLayout(container, lp)
        } catch (e: Exception) {
            Log.w(TAG, "forceOverlaySurface: ${e.message}")
        }
    }

    private fun applyLayoutToWindow() {
        val container = root ?: return
        val density = appContext.resources.displayMetrics.density
        val widthPx = overlayWidthPx(density)
        val heightPx = overlayHeightPx(widthPx)
        val lp = container.layoutParams as? WindowManager.LayoutParams ?: return
        lp.width = widthPx
        lp.height = heightPx
        applyPlacement(lp, density)
        try {
            wm.updateViewLayout(container, lp)
            Log.i(TAG, "setLayout scale=$sizeScale place=$placement ${widthPx}x${heightPx}px")
        } catch (e: Exception) {
            Log.e(TAG, "updateViewLayout failed", e)
        }
    }

}

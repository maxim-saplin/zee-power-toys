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
        private const val OVERLAY_SIDE_DP = 280
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val appContext = context.applicationContext
    private val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var enabled = false
    private var contentVisible = false

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
                            hideWindowOnly()
                            result.success(null)
                            return@post
                        }
                        contentVisible = visible
                        if (!visible) {
                            hideWindowOnly()
                            result.success(null)
                            return@post
                        }
                        ensureEngine()
                        ensureWindow(shown = true)
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
            val sidePx = (OVERLAY_SIDE_DP * density).toInt()

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
                sidePx,
                sidePx,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                x = (16 * density).toInt()
                y = (72 * density).toInt()
            }
            try {
                wm.addView(container, lp)
                fv.attachToFlutterEngine(eng)
                root = container
                flutterView = fv
                Log.i(TAG, "overlay FlutterView window added (${sidePx}px)")
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
}

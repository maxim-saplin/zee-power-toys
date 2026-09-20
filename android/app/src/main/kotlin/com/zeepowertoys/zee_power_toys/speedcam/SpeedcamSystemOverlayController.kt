package com.zeepowertoys.zee_power_toys.speedcam

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 0065 — DHU always-on-top Speedcam system overlay (TYPE_APPLICATION_OVERLAY).
 *
 * Channel [CHANNEL]: canDrawOverlays / openPermissionSettings / setEnabled /
 * update({distanceM, title, subtitle, dangerous}) / hide.
 *
 * T2: floating plate over other apps when permission granted; no-op on deny.
 */
class SpeedcamSystemOverlayController(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "ZEE/SpeedcamOverlay"
        const val CHANNEL = "zee/speedcam/system_overlay"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val wm = context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: LinearLayout? = null
    private var titleView: TextView? = null
    private var subtitleView: TextView? = null
    private var enabled = false

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
                        if (!on) hideInternal()
                        else if (canDrawOverlays()) ensureShown()
                    }
                    result.success(null)
                }
                "update" -> {
                    val distanceM = (call.argument<Number>("distanceM"))?.toDouble()
                    val title = call.argument<String>("title") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val dangerous = call.argument<Boolean>("dangerous") ?: false
                    val visible = call.argument<Boolean>("visible") ?: true
                    mainHandler.post {
                        if (!enabled || !canDrawOverlays()) {
                            hideInternal()
                            return@post
                        }
                        if (!visible) {
                            hideInternal()
                            return@post
                        }
                        ensureShown()
                        applyContent(title, subtitle, distanceM, dangerous)
                    }
                    result.success(null)
                }
                "hide" -> {
                    mainHandler.post { hideInternal() }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        Log.i(TAG, "SpeedcamSystemOverlayController registered")
    }

    fun dispose() {
        mainHandler.post { hideInternal() }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context.applicationContext)
        } else {
            true
        }
    }

    private fun openPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun ensureShown() {
        if (root != null) return
        if (!canDrawOverlays()) {
            Log.w(TAG, "ensureShown: SYSTEM_ALERT_WINDOW not granted")
            return
        }
        val density = context.resources.displayMetrics.density
        val pad = (12 * density).toInt()
        val plate = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
            setBackgroundColor(Color.argb(0xE6, 0x10, 0x10, 0x14))
            elevation = 8 * density
        }
        val title = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            text = "—"
        }
        val subtitle = TextView(context).apply {
            setTextColor(Color.argb(0xCC, 0xCC, 0xCC, 0xD0))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            text = ""
        }
        plate.addView(title)
        plate.addView(subtitle)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (24 * density).toInt()
        }
        try {
            wm.addView(plate, lp)
            root = plate
            titleView = title
            subtitleView = subtitle
            Log.i(TAG, "overlay window added")
        } catch (e: Exception) {
            Log.e(TAG, "addView failed", e)
            root = null
        }
    }

    private fun applyContent(
        title: String,
        subtitle: String,
        distanceM: Double?,
        dangerous: Boolean,
    ) {
        val t = titleView ?: return
        val s = subtitleView ?: return
        t.text = title.ifBlank {
            if (distanceM != null) "${distanceM.toInt()} m" else "Speedcam"
        }
        t.setTextColor(if (dangerous) Color.WHITE else Color.rgb(0x8F, 0xE0, 0xA0))
        s.text = subtitle
        s.visibility = if (subtitle.isBlank()) View.GONE else View.VISIBLE
        root?.visibility = View.VISIBLE
    }

    private fun hideInternal() {
        val v = root ?: return
        try {
            wm.removeView(v)
            Log.i(TAG, "overlay window removed")
        } catch (e: Exception) {
            Log.w(TAG, "removeView: ${e.message}")
        }
        root = null
        titleView = null
        subtitleView = null
    }
}

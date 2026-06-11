package com.zeepowertoys.multidisplay_poc

import android.app.ActivityManager
import android.app.Presentation
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.SurfaceTexture
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin

// THROWAWAY PoC host. One Activity, three experiments, chosen by intent extra:
//   adb shell am start -n <pkg>/.MainActivity --ei exp {1|2|3}
// Default = 1. See MainActivity.setupSecondaryDisplay().
class MainActivity : FlutterActivity() {

    companion object {
        const val TAG = "ZEEPOC"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var exp = 1

    private var presentation: Presentation? = null
    private var secondEngine: FlutterEngine? = null
    private var engineGroup: FlutterEngineGroup? = null

    // Exp 3 native "Minimap" stand-in.
    private var minimapView: MinimapView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        exp = intent?.getIntExtra("exp", 1) ?: 1
        Log.i(TAG, "onCreate: EXPERIMENT = $exp")
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine: primary engine = $flutterEngine")

        // Lean Dart -> native control API for the Minimap (Exp 3). Registered on
        // the PRIMARY engine so the DHU app drives the HUD's native surface.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zee/minimap")
            .setMethodCallHandler { call, result -> handleMinimap(call, result) }

        // Defer secondary-display setup until the primary view is up & rendering.
        handler.postDelayed({ setupSecondaryDisplay(flutterEngine) }, 1500)
    }

    private fun findSecondaryDisplay(): Display? {
        val dm = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
        val displays = dm.displays
        Log.i(TAG, "displays (${displays.size}): " +
            displays.joinToString { "[id=${it.displayId} name=${it.name} flags=${it.flags}]" })
        return displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
    }

    private fun setupSecondaryDisplay(primaryEngine: FlutterEngine) {
        val display = findSecondaryDisplay()
        if (display == null) {
            Log.e(TAG, "NO SECONDARY DISPLAY FOUND — set overlay_display_devices first")
            return
        }
        Log.i(TAG, "secondary display: id=${display.displayId} name=${display.name}")
        try {
            when (exp) {
                1 -> setupExp1SingleEngine(primaryEngine, display)
                2 -> setupExp2EngineGroup(display)
                3 -> setupExp3Transparent(display)
                else -> Log.e(TAG, "unknown exp=$exp")
            }
        } catch (t: Throwable) {
            Log.e(TAG, "EXP$exp: top-level exception during setup", t)
        }
    }

    // EXP 1 — attach a SECOND FlutterView to the SAME engine (one isolate, two views).
    private fun setupExp1SingleEngine(primaryEngine: FlutterEngine, display: Display) {
        Log.i(TAG, "EXP1: creating Presentation + 2nd FlutterView on the SAME engine")
        val pres = Presentation(this, display)
        val fv = FlutterView(pres.context, FlutterSurfaceView(pres.context))
        pres.setContentView(fv)
        pres.show()
        presentation = pres
        try {
            Log.i(TAG, "EXP1: calling attachToFlutterEngine(primaryEngine) on 2nd view")
            fv.attachToFlutterEngine(primaryEngine)
            Log.i(TAG, "EXP1: attachToFlutterEngine returned WITHOUT throwing. " +
                "isAttached=${fv.isAttachedToFlutterEngine}")
        } catch (t: Throwable) {
            Log.e(TAG, "EXP1: EXCEPTION attaching 2nd view to SAME engine", t)
        }
    }

    // EXP 2 — spawn a 2nd engine via FlutterEngineGroup (two isolates).
    private fun setupExp2EngineGroup(display: Display) {
        logPss("EXP2 MEM_BEFORE_2ND_ENGINE")
        val group = FlutterEngineGroup(this)
        engineGroup = group
        val entry = DartExecutor.DartEntrypoint(
            FlutterInjector.instance().flutterLoader().findAppBundlePath(), "hudMain")
        val eng = group.createAndRunEngine(this, entry)
        secondEngine = eng
        eng.lifecycleChannel.appIsResumed()
        Log.i(TAG, "EXP2: 2nd engine created via FlutterEngineGroup = $eng")

        val pres = Presentation(this, display)
        val fv = FlutterView(pres.context, FlutterSurfaceView(pres.context))
        pres.setContentView(fv)
        pres.show()
        presentation = pres
        fv.attachToFlutterEngine(eng)
        Log.i(TAG, "EXP2: 2nd FlutterView attached to 2nd engine; isAttached=${fv.isAttachedToFlutterEngine}")
        handler.postDelayed({ logPss("EXP2 MEM_AFTER_2ND_ENGINE") }, 2500)
    }

    // EXP 3 — native animated TextureView (Minimap) UNDER a transparent Flutter overlay.
    private fun setupExp3Transparent(display: Display) {
        Log.i(TAG, "EXP3: native TextureView UNDER transparent FlutterTextureView overlay")
        val pres = Presentation(this, display)
        val root = FrameLayout(pres.context)

        // (1) Native animated Minimap stand-in (bottom layer, opaque).
        val mm = MinimapView(pres.context)
        minimapView = mm
        root.addView(mm, FrameLayout.LayoutParams(480, 260).apply {
            leftMargin = 40; topMargin = 40
        })

        // (2) Transparent Flutter overlay (top layer) on its own engine.
        val group = FlutterEngineGroup(this)
        engineGroup = group
        val entry = DartExecutor.DartEntrypoint(
            FlutterInjector.instance().flutterLoader().findAppBundlePath(), "hudMain")
        val eng = group.createAndRunEngine(this, entry)
        secondEngine = eng
        eng.lifecycleChannel.appIsResumed()

        val ftv = FlutterTextureView(pres.context)
        ftv.isOpaque = false // <- the key bit for transparency compositing
        val fv = FlutterView(pres.context, ftv)
        root.addView(fv, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

        pres.setContentView(root)
        pres.show()
        presentation = pres
        fv.attachToFlutterEngine(eng)
        Log.i(TAG, "EXP3: overlay attached; ftv.isOpaque=${ftv.isOpaque} isAttached=${fv.isAttachedToFlutterEngine}")
    }

    // Lean idempotent Dart -> native control API for the Minimap surface.
    private fun handleMinimap(call: MethodCall, result: MethodChannel.Result) {
        handler.post {
            val v = minimapView
            if (v == null) {
                Log.i(TAG, "minimap.${call.method}: no native minimap (exp=$exp)")
                result.success("no-minimap(exp=$exp)")
                return@post
            }
            when (call.method) {
                "setMinimap" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val want = if (enabled) View.VISIBLE else View.INVISIBLE
                    if (v.visibility == want) {
                        Log.i(TAG, "setMinimap($enabled): NOOP (already ${if (enabled) "shown" else "hidden"})")
                        result.success("noop")
                    } else {
                        v.visibility = want
                        Log.i(TAG, "setMinimap($enabled): APPLIED")
                        result.success("applied:$enabled")
                    }
                }
                "setMinimapBounds" -> {
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    val w = call.argument<Int>("w") ?: 100
                    val h = call.argument<Int>("h") ?: 100
                    v.layoutParams = FrameLayout.LayoutParams(w, h).apply {
                        leftMargin = x; topMargin = y
                    }
                    v.requestLayout()
                    Log.i(TAG, "setMinimapBounds($x,$y,$w,$h): APPLIED")
                    result.success("bounds:$x,$y,$w,$h")
                }
                "setMinimapParam" -> {
                    val key = call.argument<String>("key") ?: ""
                    if (key == "hue") {
                        val value = (call.argument<Double>("value") ?: 0.0).toFloat()
                        v.baseHue = ((value % 360f) + 360f) % 360f
                        Log.i(TAG, "setMinimapParam(hue=${v.baseHue}): APPLIED")
                        result.success("hue:${v.baseHue}")
                    } else {
                        Log.i(TAG, "setMinimapParam($key): ignored")
                        result.success("ignored:$key")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun logPss(tag: String) {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = am.getProcessMemoryInfo(intArrayOf(android.os.Process.myPid()))[0]
        Log.i(TAG, "$tag pss=${info.totalPss}kB privateDirty=${info.totalPrivateDirty}kB")
    }

    override fun onDestroy() {
        try { presentation?.dismiss() } catch (_: Throwable) {}
        secondEngine?.destroy()
        super.onDestroy()
    }
}

// Native animated "Minimap" stand-in: a TextureView with a render thread
// drawing a moving gradient + circle. No video/maps — just motion + color.
class MinimapView(context: Context) : TextureView(context), TextureView.SurfaceTextureListener {
    @Volatile var baseHue: Float = 200f
    @Volatile private var running = false
    private var renderThread: Thread? = null

    init {
        isOpaque = true
        surfaceTextureListener = this
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        running = true
        renderThread = Thread {
            var phase = 0f
            while (running) {
                val canvas: Canvas = try { lockCanvas() } catch (_: Throwable) { null } ?: continue
                try {
                    phase = (phase + 3f) % 360f
                    val w = canvas.width.toFloat()
                    val h = canvas.height.toFloat()
                    val c1 = Color.HSVToColor(floatArrayOf((baseHue + phase) % 360f, 0.7f, 0.85f))
                    val c2 = Color.HSVToColor(floatArrayOf((baseHue + phase + 120f) % 360f, 0.7f, 0.5f))
                    val bg = Paint().apply {
                        shader = LinearGradient(0f, 0f, w, h, c1, c2, Shader.TileMode.CLAMP)
                    }
                    canvas.drawRect(0f, 0f, w, h, bg)
                    val cx = w * (0.5f + 0.4f * sin(Math.toRadians(phase.toDouble())).toFloat())
                    canvas.drawCircle(cx, h * 0.5f, h * 0.14f,
                        Paint().apply { color = Color.WHITE; isAntiAlias = true })
                    canvas.drawText("MINIMAP (native)", 16f, h * 0.18f,
                        Paint().apply { color = Color.BLACK; textSize = h * 0.12f; isAntiAlias = true })
                } finally {
                    unlockCanvasAndPost(canvas)
                }
                try { Thread.sleep(16) } catch (_: InterruptedException) { break }
            }
        }.also { it.start() }
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        running = false
        renderThread?.interrupt()
        renderThread = null
        return true
    }
    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
}

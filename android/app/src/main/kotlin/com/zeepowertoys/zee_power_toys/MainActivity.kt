package com.zeepowertoys.zee_power_toys

import android.app.Presentation
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.SurfaceTexture
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import com.zeepowertoys.zee_power_toys.boot.ConfigShim
import com.zeepowertoys.zee_power_toys.boot.ZeeForegroundService
import com.zeepowertoys.zee_power_toys.carsignals.CarSignalsController
import com.zeepowertoys.zee_power_toys.carsignals.SimulateReceiver
import com.zeepowertoys.zee_power_toys.install.InstallerController
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin

// Two-engine host for T2 (Android).
//
// The primary engine (DHU) is the standard FlutterActivity engine.
// A second engine (HUD) is spawned via FlutterEngineGroup onto a secondary
// display Presentation ~1.5 s after the primary view is up (ADR 0001/0005).
//
// Cross-engine relay bridge (ADR 0003):
//   DHU-side "zee/hub" handler forwards every "relay" call to the HUD-side
//   "zee/hub" channel.  Unidirectional DHU→HUD, mirroring the desktop hub.
//
// CarSignals bridge (ADR 0002/Block 0005):
//   CarSignalsController registers on the DHU engine messenger only.
//   It auto-selects AdaptAPI or Simulator and exposes:
//     MethodChannel "zee/car_signals"         — start() / snapshot()
//     EventChannel  "zee/car_signals/events"  — streamed signal events
//   The HUD engine receives signals via the existing relay (not the native bridge).
//
// Minimap under-layer (Block 0009, ADR 0001 exception):
//   The HUD Presentation uses a FrameLayout with a native MinimapView (TextureView,
//   green-yellow ColorMatrix filter) UNDER a transparent FlutterTextureView overlay.
//   The zee/minimap MethodChannel is registered on the DHU engine (primary) so
//   the DHU Dart isolate drives the native Minimap surface.
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ZEE"
        private const val HUB_CHANNEL = "zee/hub"
        private const val MINIMAP_CHANNEL = "zee/minimap"
        private const val BOOT_CHANNEL = "zee/boot"
        // Delay (ms) before spawning the HUD engine; lets the primary view
        // finish its first layout pass so the FlutterView is fully attached.
        private const val HUD_SPAWN_DELAY_MS = 1500L
    }

    private val handler = Handler(Looper.getMainLooper())

    private var hudEngine: FlutterEngine? = null
    private var engineGroup: FlutterEngineGroup? = null
    private var hudPresentation: Presentation? = null

    // Native relay channels — held so the DHU handler can forward to HUD.
    private var dhuHub: MethodChannel? = null
    private var hudHub: MethodChannel? = null

    // CarSignals native bridge — DHU engine only.
    private var carSignalsController: CarSignalsController? = null

    // Installer native bridge — DHU engine only (Block 0014).
    private var installerController: InstallerController? = null

    // SystemConfig native bridge — DHU engine only (Block 0015).
    private var systemConfigController: SystemConfigController? = null

    // Minimap native surface — created in setupHud; driven via zee/minimap channel.
    private var minimapView: MinimapView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine: primary DHU engine = $flutterEngine")

        // Register the DHU side of the relay bridge.  Every "relay" call from
        // the DHU Dart isolate is forwarded here to the HUD Dart isolate.
        val dhu = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HUB_CHANNEL)
        dhuHub = dhu
        dhu.setMethodCallHandler { call, result ->
            if (call.method == "relay") {
                val hud = hudHub
                if (hud != null) {
                    // Forward the serialised envelope to the HUD isolate.
                    hud.invokeMethod("relay", call.arguments)
                } else {
                    Log.d(TAG, "relay: HUD engine not ready yet — dropping ${call.arguments}")
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Register the zee/minimap MethodChannel on the DHU (primary) engine.
        // The DHU Dart isolate drives the native Minimap surface via this channel
        // (ADR 0001 exception: native map under transparent Flutter overlay).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MINIMAP_CHANNEL)
            .setMethodCallHandler { call, result -> handleMinimap(call, result) }

        // Register the zee/boot MethodChannel — exposes FGS/boot state to Dart
        // for ext.zee.bootState (Block 0010).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BOOT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBootState" -> {
                        val hudEnabledCfg = ConfigShim.readHudEnabled(applicationContext)
                        result.success(mapOf(
                            "fgsRunning" to ZeeForegroundService.isRunning,
                            "hudEnabled" to ZeeForegroundService.lastHudEnabled,
                            "hudEnabledConfig" to hudEnabledCfg,
                            "configReadOk" to true,
                        ))
                    }
                    else -> result.notImplemented()
                }
            }

        // Construct CarSignalsController on the DHU engine messenger.
        // selectSource() probes AdaptAPI availability and logs the chosen source.
        val ctrl = CarSignalsController(this, flutterEngine.dartExecutor.binaryMessenger)
        ctrl.selectSource()
        carSignalsController = ctrl
        // Expose to SimulateReceiver so ADB broadcasts reach the live source.
        SimulateReceiver.controllerRef = ctrl

        // Construct InstallerController on the DHU engine messenger (Block 0014).
        // Registers zee/installer MethodChannel and zee/installer/events EventChannel.
        installerController = InstallerController(this, flutterEngine.dartExecutor.binaryMessenger)

        // Construct SystemConfigController on the DHU engine messenger (Block 0015).
        // Registers zee/system_config MethodChannel for systemLocale read + guarded writes.
        systemConfigController = SystemConfigController(this, flutterEngine.dartExecutor.binaryMessenger)

        // Defer HUD setup: give the primary view time to attach and render.
        handler.postDelayed({ setupHud() }, HUD_SPAWN_DELAY_MS)
    }

    // -------------------------------------------------------------------------
    // HUD engine setup (Block 0009: Minimap under-layer)
    // -------------------------------------------------------------------------

    private fun setupHud() {
        // Gate: read hudEnabled from config before spawning the HUD engine.
        // ConfigShim is the ADR 0003 privileged pre-Flutter read; here the
        // Flutter isolate may already be running, but using the same source
        // (SharedPreferences) avoids a Dart↔native round-trip at startup.
        val hudEnabled = ConfigShim.readHudEnabled(applicationContext)
        if (!hudEnabled) {
            Log.i(TAG, "setupHud: hudEnabled=false — HUD engine NOT spawned (config gate)")
            return
        }
        Log.i(TAG, "setupHud: hudEnabled=true — proceeding with HUD engine setup")

        val display = findSecondaryDisplay()
        if (display == null) {
            // Graceful degradation: DHU keeps running, HUD simply absent.
            Log.w(TAG, "setupHud: no secondary display found — HUD engine not started. " +
                "Run: adb shell settings put global overlay_display_devices \"1280x720/213\"")
            return
        }
        Log.i(TAG, "setupHud: secondary display id=${display.displayId} name=${display.name}")

        try {
            // Spawn the HUD engine from a FlutterEngineGroup so VM snapshot /
            // GPU context are shared with the primary engine (ADR 0001 memory note).
            val group = FlutterEngineGroup(this)
            engineGroup = group

            val entry = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "hudEntry",   // matches @pragma('vm:entry-point') void hudEntry() in main.dart
            )
            val eng = group.createAndRunEngine(this, entry)
            hudEngine = eng

            // The lifecycle channel must be signalled or the engine stays paused
            // and the Dart code never runs past WidgetsFlutterBinding.ensureInitialized().
            eng.lifecycleChannel.appIsResumed()
            Log.i(TAG, "setupHud: HUD engine created = $eng")

            // Register the HUD side of the relay bridge.  The HUD Dart isolate
            // calls setMethodCallHandler("zee/hub") in hudMain → listenForRelay;
            // this channel delivers those "relay" method calls inbound.
            val hud = MethodChannel(eng.dartExecutor.binaryMessenger, HUB_CHANNEL)
            hudHub = hud
            // (HUD side only listens; no handler needed on the native side here.)

            // Build the Presentation layer stack (EXP3 pattern from the PoC):
            //   (1) MinimapView — native TextureView with green-yellow ColorMatrix
            //       filter (ADR 0001 exception: native map under transparent Flutter).
            //   (2) FlutterTextureView (isOpaque=false) — transparent HUD overlay
            //       attached to the HUD engine; Flutter Scaffold must also use
            //       backgroundColor: Colors.transparent so the native layer shows.
            val pres = Presentation(this, display)
            val root = FrameLayout(pres.context)

            // Layer 1 (bottom): native animated Minimap stand-in with HUD colour filter.
            val mm = MinimapView(pres.context)
            minimapView = mm
            root.addView(mm, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))

            // Layer 2 (top): transparent Flutter overlay.
            // isOpaque=false is what enables compositing over the MinimapView;
            // without this the SurfaceTexture renders opaque black.
            val ftv = FlutterTextureView(pres.context)
            ftv.isOpaque = false
            val fv = FlutterView(pres.context, ftv)
            root.addView(fv, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))

            pres.setContentView(root)
            pres.show()
            hudPresentation = pres
            fv.attachToFlutterEngine(eng)
            Log.i(TAG, "setupHud: transparent FlutterTextureView attached to HUD engine; " +
                "ftv.isOpaque=${ftv.isOpaque} isAttached=${fv.isAttachedToFlutterEngine}")
        } catch (t: Throwable) {
            Log.e(TAG, "setupHud: exception during HUD setup", t)
        }
    }

    // -------------------------------------------------------------------------
    // Minimap control — idempotent zee/minimap MethodChannel handler.
    //
    // Registered on the DHU (primary) engine so the DHU Dart isolate drives the
    // native Minimap surface (ADR 0001 exception: native under transparent Flutter).
    // All View mutations are posted to the main looper for thread-safety.
    // -------------------------------------------------------------------------

    private fun handleMinimap(call: MethodCall, result: MethodChannel.Result) {
        // isYnaviAvailable does not need the minimapView; handle it on the main thread directly.
        if (call.method == "isYnaviAvailable") {
            result.success(isYnaviAvailable())
            return
        }
        handler.post {
            val v = minimapView
            if (v == null) {
                // HUD not yet set up (e.g. no secondary display); safe to ignore.
                Log.i(TAG, "minimap.${call.method}: no native minimap yet")
                result.success("no-minimap")
                return@post
            }
            when (call.method) {
                "setMinimap" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val want = if (enabled) View.VISIBLE else View.INVISIBLE
                    if (v.visibility == want) {
                        // Idempotent: NOOP when already in the requested state.
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
                    val w = call.argument<Int>("w") ?: FrameLayout.LayoutParams.MATCH_PARENT
                    val h = call.argument<Int>("h") ?: FrameLayout.LayoutParams.MATCH_PARENT
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

    // -------------------------------------------------------------------------
    // YNavi mod detection — isYnaviAvailable (zee/minimap channel, no-HUD-needed).
    //
    // Implements detection Steps 1+2 from ynavi-bind-and-mod.md §7:
    //   1. PackageManager.getPackageInfo("ru.yandex.yandexnavi", GET_SERVICES)
    //   2. Services list contains NavigationCarAppService
    //
    // This is a static check (no bind attempt) — fast and safe to call from Dart
    // on every screen open.  Returns false when the package is absent (emulator,
    // stock device) or only the stock APK is installed (service present but the
    // bind allowlist patch P1 is not applied — Step 3 bind probe would be needed
    // to distinguish this, deferred to T3).
    // -------------------------------------------------------------------------
    private fun isYnaviAvailable(): Boolean {
        return try {
            val flags = if (android.os.Build.VERSION.SDK_INT >= 33) {
                android.content.pm.PackageManager.PackageInfoFlags.of(
                    android.content.pm.PackageManager.GET_SERVICES.toLong()
                )
            } else {
                null
            }
            val pkgInfo = if (flags != null) {
                packageManager.getPackageInfo("ru.yandex.yandexnavi", flags)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    "ru.yandex.yandexnavi",
                    android.content.pm.PackageManager.GET_SERVICES,
                )
            }
            // Service presence check: the mod must declare NavigationCarAppService.
            val hasService = pkgInfo.services?.any { svc ->
                svc.name == "ru.yandex.yandexnavi.projected.platformkit.presentation.service.NavigationCarAppService"
                    || svc.name.endsWith(".NavigationCarAppService")
            } == true
            Log.i(TAG, "isYnaviAvailable: package found, hasService=$hasService")
            hasService
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            Log.i(TAG, "isYnaviAvailable: package not found → false")
            false
        }
    }

    // -------------------------------------------------------------------------
    // Display discovery — first non-default display is the HUD (emulator uses
    // the overlay_display_devices virtual display; car uses displayId=2).
    // -------------------------------------------------------------------------

    private fun findSecondaryDisplay(): Display? {
        val dm = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = dm.displays
        Log.i(TAG, "findSecondaryDisplay: ${displays.size} display(s): " +
            displays.joinToString { "[id=${it.displayId} name=${it.name}]" })
        return displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
    }

    // -------------------------------------------------------------------------
    // Lifecycle cleanup
    // -------------------------------------------------------------------------

    override fun onDestroy() {
        SimulateReceiver.controllerRef = null
        carSignalsController?.tearDown()
        carSignalsController = null
        installerController?.tearDown()
        installerController = null
        systemConfigController?.tearDown()
        systemConfigController = null
        try { hudPresentation?.dismiss() } catch (_: Throwable) {}
        hudEngine?.destroy()
        super.onDestroy()
    }
}

// -----------------------------------------------------------------------------
// MinimapView — native animated TextureView placeholder for the map under-layer.
//
// Draws a moving gradient + circle on a dedicated render thread (~60 fps).
// The green-yellow HUD-readability ColorMatrix filter is applied via
// setLayerType(LAYER_TYPE_HARDWARE, filterPaint) on the VIEW ITSELF here because
// we control the drawing; the PoC applies it on a filterWrapper FrameLayout
// parent only when using an external SurfaceTexture (e.g. YNavi) that bypasses
// View invalidation.  For our own lockCanvas loop the direct approach works.
//
// Color-filter values (preset 1 "Green-yellow" from hud-presentation-host.md):
//   filterPreset=0 → tR=0.7, tG=1.0, tB=0.1; contrast=3.0; threshold=-150;
//   brightness=-20; saturation=0 (full monochrome-tint).
// The compact matrix below encodes the preset-0 tint at those params
// (computed offline from the CarAppHostService matrix formula).
// -----------------------------------------------------------------------------
class MinimapView(context: android.content.Context) :
    TextureView(context), TextureView.SurfaceTextureListener {

    @Volatile var baseHue: Float = 120f // green-yellow hue
    @Volatile private var running = false
    private var renderThread: Thread? = null

    init {
        // The native layer must be opaque so the FilterWrapper colour shows
        // through clearly; the transparent Flutter overlay sits on top.
        isOpaque = true
        surfaceTextureListener = this

        // Apply the HUD-readability green-yellow ColorMatrix filter as a
        // hardware layer directly on this TextureView.  We own the drawing
        // (lockCanvas loop), so View invalidation keeps the layer current.
        //
        // Compact green-yellow tint matrix (monochrome, contrast ×3, t=-150,
        // brightness -20, tR=0.7 tG=1.0 tB=0.1) from hud-presentation-host.md:
        //   L = 0.3R+0.6G+0.1B  (luminance)
        //   out_R = 3*0.7*L - 150*0.7 - 20 = 2.1L - 125
        //   out_G = 3*1.0*L - 150*1.0 - 20 = 3.0L - 170
        //   out_B = 3*0.1*L - 150*0.1 - 20 = 0.3L -  35
        val cm = ColorMatrix(floatArrayOf(
            // R row:  rR,   rG,   rB,  rA,  rOffset
            0.63f,  1.26f, 0.21f, 0f, -125f,
            // G row:  gR,   gG,   gB,  gA,  gOffset
            0.90f,  1.80f, 0.30f, 0f, -170f,
            // B row:  bR,   bG,   bB,  bA,  bOffset
            0.09f,  0.18f, 0.03f, 0f,  -35f,
            // A row (pass-through)
            0f,     0f,    0f,   1f,    0f,
        ))
        val paint = Paint().apply { colorFilter = ColorMatrixColorFilter(cm) }
        setLayerType(LAYER_TYPE_HARDWARE, paint)
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
                    // Animated background gradient — base hue shifts with phase.
                    val c1 = Color.HSVToColor(floatArrayOf((baseHue + phase) % 360f, 0.7f, 0.85f))
                    val c2 = Color.HSVToColor(floatArrayOf((baseHue + phase + 120f) % 360f, 0.7f, 0.5f))
                    val bg = Paint().apply {
                        shader = LinearGradient(0f, 0f, w, h, c1, c2, Shader.TileMode.CLAMP)
                    }
                    canvas.drawRect(0f, 0f, w, h, bg)
                    // Moving circle — represents a map marker.
                    val cx = w * (0.5f + 0.4f * sin(Math.toRadians(phase.toDouble())).toFloat())
                    canvas.drawCircle(cx, h * 0.5f, h * 0.14f,
                        Paint().apply { color = Color.WHITE; isAntiAlias = true })
                    // Label so the filter effect is visually obvious.
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

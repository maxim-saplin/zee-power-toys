package com.zeepowertoys.zee_power_toys

import android.app.Presentation
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
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
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.zeepowertoys.zee_power_toys.boot.ConfigShim
import com.zeepowertoys.zee_power_toys.boot.ZeeForegroundService
import com.zeepowertoys.zee_power_toys.carapp.YNaviCarAppHost
import com.zeepowertoys.zee_power_toys.carsignals.CarSignalsController
import com.zeepowertoys.zee_power_toys.carsignals.SimulateReceiver
import com.zeepowertoys.zee_power_toys.install.InstallerController
import com.zeepowertoys.zee_power_toys.usb.UsbModeController
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
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
        private const val MINIMAP_GUIDANCE_CHANNEL = "zee/minimap/guidance"
        private const val BOOT_CHANNEL = "zee/boot"
        // HUD lifecycle channel — Dart calls show()/hide() to spawn/destroy the HUD engine (QA4-1).
        private const val HUD_LIFECYCLE_CHANNEL = "zee/hud_lifecycle"
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

    // HUD presentation display — the secondary display the MinimapView lives on.
    // Held so the YNavi SurfaceContainer is built from the HUD surface metrics
    // (density / size), not the DHU/primary density (resources.displayMetrics).
    private var hudDisplay: Display? = null

    // CarSignals native bridge — DHU engine only.
    private var carSignalsController: CarSignalsController? = null

    // Installer native bridge — DHU engine only (Block 0014).
    private var installerController: InstallerController? = null

    // SystemConfig native bridge — DHU engine only (Block 0015).
    private var systemConfigController: SystemConfigController? = null

    // UsbMode native bridge — DHU engine only (Block 0016).
    private var usbModeController: UsbModeController? = null

    // Minimap native surface — created in setupHud; driven via zee/minimap channel.
    private var minimapView: MinimapView? = null

    // YNavi CarApp host — binds to YNavi and feeds the MinimapView surface.
    // Null when YNavi is unavailable or the minimap is disabled.
    // Internal visibility so MinimapView can check isActive for exclusive surface ownership.
    internal var yNaviCarAppHost: YNaviCarAppHost? = null

    // Guidance EventChannel sink — set when Dart subscribes to zee/minimap/guidance.
    @Volatile private var guidanceSink: EventChannel.EventSink? = null

    // DHU minimap MethodChannel — stored so setupHud() can invoke native→Dart hudReady (QA1-2/QA1-4).
    private var dhuMinimapChannel: MethodChannel? = null

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
        // Store the channel so setupHud() can send native→Dart hudReady notifications (QA1-2/QA1-4).
        val minimapCh = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MINIMAP_CHANNEL)
        minimapCh.setMethodCallHandler { call, result -> handleMinimap(call, result) }
        dhuMinimapChannel = minimapCh

        // Register zee/hud_lifecycle MethodChannel for dynamic HUD engine show/hide (QA4-1).
        // show() → (re-)spawns HUD engine via setupHud(); hide() → tears down engine + Presentation.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HUD_LIFECYCLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> handler.post {
                        if (hudEngine == null) setupHud()
                        result.success(null)
                    }
                    "hide" -> handler.post {
                        tearDownHud()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register the zee/minimap/guidance EventChannel for trip data from YNavi.
        // When YNavi sends a trip update, the ICarHostStub fires onTripUpdated →
        // YNaviCarAppHost.onTrip → this sink → Dart GuidanceEvent.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MINIMAP_GUIDANCE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    guidanceSink = sink
                    Log.i(TAG, "guidance EventChannel: Dart subscribed")
                }
                override fun onCancel(arguments: Any?) {
                    guidanceSink = null
                    Log.i(TAG, "guidance EventChannel: Dart unsubscribed")
                }
            })

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

        // Construct UsbModeController on the DHU engine messenger (Block 0016).
        // Registers zee/usb_mode MethodChannel for getUsbMode + guarded setUsbMode.
        usbModeController = UsbModeController(this, flutterEngine.dartExecutor.binaryMessenger)

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
        hudDisplay = display

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
            // Emissive-black rule (QA1-1): black window + root prevents near-white backing
            // from showing through wherever the minimap / Flutter overlay does not cover.
            pres.window?.setBackgroundDrawable(ColorDrawable(Color.BLACK))
            val root = FrameLayout(pres.context)
            root.setBackgroundColor(Color.BLACK)

            // Layer 1 (bottom): native Minimap / YNavi surface with HUD colour filter.
            // The TextureView is wrapped in a FrameLayout (filterWrapper) so the hardware-
            // layer ColorMatrix is applied on the PARENT — applying it directly on the
            // TextureView does NOT filter SurfaceTexture content (see hud-presentation-host.md §7).
            val mm = MinimapView(pres.context).also { it.mainActivity = this }
            minimapView = mm
            val filterWrapper = FrameLayout(pres.context)
            filterWrapper.addView(mm, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))
            mm.filterWrapper = filterWrapper
            filterWrapper.setLayerType(View.LAYER_TYPE_HARDWARE, createHudFilterPaint())
            root.addView(filterWrapper, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))

            // Construct the YNavi CarApp host controller.
            // It is started (bound) when the Dart side calls setMinimap(enabled=true)
            // and YNavi is available; the MinimapView's SurfaceTexture is the surface.
            yNaviCarAppHost = YNaviCarAppHost(this).also { host ->
                // Trip updates → guidance EventChannel → Dart GuidanceEvent.
                host.onTrip = { trip ->
                    val step = trip.steps.firstOrNull()
                    val stepEst = trip.stepTravelEstimates.firstOrNull()
                    val destEst = trip.destinationTravelEstimates.firstOrNull()
                    val event = mapOf(
                        "turnIcon" to (step?.maneuver?.type?.toString()),
                        "distanceM" to (stepEst?.remainingDistance?.displayDistance?.toInt()),
                        "roadName" to (step?.cue?.toString() ?: trip.currentRoad?.toString()),
                        "etaMin" to (destEst?.remainingTimeSeconds?.let { (it / 60).toInt() }),
                    )
                    guidanceSink?.success(event)
                }
                host.onNavState = { active ->
                    Log.i(TAG, "YNavi navigation active=$active")
                }
            }

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

            // Notify DHU Dart of the actual HUD display dimensions (QA1-2, QA1-4).
            // This fires hudReady in NativeMinimapHost which re-applies minimap config
            // with the real 1280×720 metrics (not the hardcoded 1024×576 fallback).
            val hudDm = DisplayMetrics().also { display.getMetrics(it) }
            dhuMinimapChannel?.invokeMethod(
                "hudReady",
                mapOf("w" to hudDm.widthPixels, "h" to hudDm.heightPixels, "dpi" to hudDm.densityDpi)
            )
        } catch (t: Throwable) {
            Log.e(TAG, "setupHud: exception during HUD setup", t)
        }
    }

    // -------------------------------------------------------------------------
    // HUD engine teardown — invoked from zee/hud_lifecycle hide() (QA4-1).
    // Idempotent: safe to call when the engine is already gone.
    // -------------------------------------------------------------------------

    private fun tearDownHud() {
        Log.i(TAG, "tearDownHud: stopping HUD engine + Presentation")
        val v = minimapView
        if (v != null) {
            val host = yNaviCarAppHost
            if (host != null && host.isActive) host.stop()
            v.pendingYNaviStart = false
            v.pauseRendering()   // now also stops the render thread (QA4-4)
            minimapView = null
        }
        yNaviCarAppHost = null
        guidanceSink = null
        hudDisplay = null
        hudHub = null
        try { hudPresentation?.dismiss() } catch (_: Throwable) {}
        hudPresentation = null
        hudEngine?.destroy()
        hudEngine = null
        engineGroup = null
        Log.i(TAG, "tearDownHud: done — engine + Presentation destroyed")
    }

    // -------------------------------------------------------------------------
    // HUD filter — parametric ColorMatrix with hue passthrough.
    // Ported from phase0 CarAppHostService.createHudFilterPaint (hud-presentation-host.md §7).
    // Defaults: contrast=3.0, threshold=150, preset=0 (green-yellow), saturation=0 (fully
    // monochrome-tinted), brightness=-20, huePass=1.0, hueAngle=120 (green).
    // threshold=150 maps pixels darker than ~150/255 to BLACK → dark emissive background.
    // huePass=1.0 + hueAngle=120 keeps green/yellow map features in color; all else → mono.
    // -------------------------------------------------------------------------

    private fun createHudFilterPaint(
        contrast: Float = 3.0f,
        threshold: Int = 150,
        preset: Int = 0,         // 0=green-yellow (default), 1=cyan, 2=white, 3=amber, 4=red
        saturation: Float = 0f,
        brightness: Int = -20,
        invert: Boolean = false,
        huePass: Float = 1.0f,
        hueAngle: Int = 120,     // degrees: 0=red, 60=yellow, 120=green, 180=cyan, 240=blue
    ): Paint {
        val (tR, tG, tB) = when (preset) {
            1 -> Triple(0.1f, 0.9f, 1.0f)    // cyan
            2 -> Triple(1.0f, 1.0f, 1.0f)    // white
            3 -> Triple(1.0f, 0.75f, 0.0f)   // amber
            4 -> Triple(1.0f, 0.15f, 0.0f)   // red
            else -> Triple(0.7f, 1.0f, 0.1f) // green-yellow (preset=0, default)
        }
        val c = contrast
        val t = -threshold.toFloat()
        val s = saturation.coerceIn(0f, 1f)
        val ms = 1f - s   // monochrome weight
        val b = brightness.toFloat()
        val hp = huePass.coerceIn(0f, 1f)
        val lr = 0.3f; val lg = 0.6f; val lb = 0.1f

        // Base coefficients per output channel (monochrome-tint + saturation blend).
        val rR = ms * lr * c * tR + s * c;  val rG_r = ms * lg * c * tR;          val rB_r = ms * lb * c * tR
        val gR = ms * lr * c * tG;          val gG = ms * lg * c * tG + s * c;    val gB_g = ms * lb * c * tG
        val bR = ms * lr * c * tB;          val bG_b = ms * lg * c * tB;          val bB = ms * lb * c * tB + s * c
        val rOff = ms * t * tR + s * t + b
        val gOff = ms * t * tG + s * t + b
        val bOff = ms * t * tB + s * t + b

        // Per-channel hue passthrough: triangle peaking at each channel's primary hue
        // (R=0°, G=120°, B=240°), 120° half-width.  At huePass=1.0 + hueAngle=120 the
        // green channel row is replaced by identity-contrast, keeping map road colours
        // green/yellow while the dark background is zeroed by the threshold.
        val angle = (hueAngle % 360).toFloat()
        fun hueWeight(primary: Float): Float {
            val d = Math.abs(((angle - primary + 180f) % 360f) - 180f)
            return (1f - d / 120f).coerceIn(0f, 1f)
        }
        val hpR = hp * hueWeight(0f)
        val hpG = hp * hueWeight(120f)
        val hpB = hp * hueWeight(240f)

        val cm = ColorMatrix(floatArrayOf(
            rR * (1f - hpR) + c * hpR,  rG_r * (1f - hpR),           rB_r * (1f - hpR),           0f, rOff * (1f - hpR) + (t + b) * hpR,
            gR * (1f - hpG),            gG * (1f - hpG) + c * hpG,   gB_g * (1f - hpG),           0f, gOff * (1f - hpG) + (t + b) * hpG,
            bR * (1f - hpB),            bG_b * (1f - hpB),           bB * (1f - hpB) + c * hpB,   0f, bOff * (1f - hpB) + (t + b) * hpB,
            0f,                         0f,                          0f,                          1f, 0f,
        ))

        if (invert) {
            val inv = ColorMatrix(floatArrayOf(
                -1f, 0f,  0f,  0f, 255f,
                 0f, -1f, 0f,  0f, 255f,
                 0f, 0f,  -1f, 0f, 255f,
                 0f, 0f,  0f,  1f,   0f,
            ))
            cm.preConcat(inv)
        }
        return Paint().apply { colorFilter = ColorMatrixColorFilter(cm) }
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
                    // Visibility is managed idempotently, but the YNavi host lifecycle
                    // is driven by the enabled + host-active state, INDEPENDENT of whether
                    // the View visibility happened to change. On startup the MinimapView
                    // defaults to VISIBLE, so gating host.start() behind a visibility
                    // transition would NOOP setMinimap(true) and never bind YNavi.
                    val want = if (enabled) View.VISIBLE else View.INVISIBLE
                    if (v.visibility != want) v.visibility = want

                    if (enabled) {
                        val host = yNaviCarAppHost
                        if (host != null && isYnaviAvailable()) {
                            if (host.isActive) {
                                // YNavi already hosting — nothing to (re)start.
                                Log.i(TAG, "setMinimap(true): YNavi host already active — NOOP")
                            } else {
                                // Hand the MinimapView surface over to YNavi.
                                // If the surface is already available, start immediately;
                                // otherwise onSurfaceTextureAvailable starts on availability.
                                // Park the placeholder render loop and hand the surface to YNavi.
                                    // parkForYNavi() stops the render thread, sets
                                    // pendingYNaviStart=true, and removes/re-adds the view to
                                    // trigger a full TextureView lifecycle cycle that frees
                                    // the api=2 Canvas producer and creates a fresh
                                    // GL-attached SurfaceTexture.  host.start() is called
                                    // from startYNaviOnSurfaceReady() when
                                    // onSurfaceTextureAvailable fires — NOT here.
                                    v.parkForYNavi()
                                    Log.i(TAG, "setMinimap(true): parkForYNavi called — YNavi start deferred to onSurfaceTextureAvailable")
                            }
                        } else {
                            // YNavi unavailable — fall back to placeholder render loop.
                            v.resumeRendering()
                            Log.i(TAG, "setMinimap(true): YNavi unavailable — placeholder resumed")
                        }
                    } else {
                        // Disable: stop YNavi host (if running) and park placeholder.
                        val host = yNaviCarAppHost
                        if (host != null && host.isActive) {
                            host.stop()
                            Log.i(TAG, "setMinimap(false): YNavi host stopped")
                        }
                        v.pendingYNaviStart = false
                        v.pauseRendering()  // view is INVISIBLE; keep loop parked
                    }
                    Log.i(TAG, "setMinimap($enabled): APPLIED")
                    result.success("applied:$enabled")
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
    // YNavi host helpers
    // -------------------------------------------------------------------------

    /**
     * Density (dpi) of the HUD presentation display the MinimapView lives on.
     *
     * The SurfaceContainer handed to YNavi must describe the HUD surface, NOT the
     * DHU/primary density (resources.displayMetrics) — the MinimapView renders on
     * the secondary display, whose density drives YNavi's dp→px scaling.
     * Falls back to the activity density if the display metrics are unavailable
     * (clamped to a sane range so a bogus value never reaches YNavi).
     */
    private fun hudDensityDpi(): Int {
        val dpi = hudDisplay?.let { d ->
            DisplayMetrics().also { d.getMetrics(it) }.densityDpi
        } ?: resources.displayMetrics.densityDpi
        return if (dpi in 120..960) dpi else resources.displayMetrics.densityDpi
    }

    /**
     * Called by MinimapView when its SurfaceTexture becomes available and
     * [MinimapView.pendingYNaviStart] is set.  Starts the YNavi host if YNavi
     * is available; otherwise falls through to placeholder rendering.
     */
    internal fun startYNaviOnSurfaceReady(surface: SurfaceTexture, width: Int, height: Int) {
        val host = yNaviCarAppHost ?: return
        if (isYnaviAvailable()) {
            val dpi = hudDensityDpi()
            // Oversample the buffer at 2× (minimapScale=0.5): tells YNavi to render
            // a larger map area which the compositor scales down to viewport size,
            // giving a zoom-out effect for better readability (phase0 §6 pattern).
            val bufW = width * 2
            val bufH = height * 2
            surface.setDefaultBufferSize(bufW, bufH)
            host.start(Surface(surface), bufW, bufH, dpi)
            Log.i(TAG, "startYNaviOnSurfaceReady: YNavi host started w=$width h=$height buf=${bufW}x${bufH} dpi=$dpi")
        } else {
            minimapView?.resumeRendering()
            Log.i(TAG, "startYNaviOnSurfaceReady: YNavi unavailable — placeholder resumed")
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
        usbModeController?.tearDown()
        usbModeController = null
        dhuMinimapChannel = null
        tearDownHud()
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
// When YNavi is available:
//   - parkForYNavi()  : stops the placeholder render loop; YNavi owns the surface.
//   - pendingYNaviStart: set true when setMinimap(true) is called before the
//     SurfaceTexture is ready; onSurfaceTextureAvailable calls back to MainActivity
//     to start the YNavi host when the surface finally exists.
//   - On YNavi disconnect / minimap disable: resumeRendering() restores the
//     placeholder so devices without the mod still show something.
//
// Color-filter values (preset 1 "Green-yellow" from hud-presentation-host.md):
//   filterPreset=0 → tR=0.7, tG=1.0, tB=0.1; contrast=3.0; threshold=-150;
//   brightness=-20; saturation=0 (full monochrome-tint).
// -----------------------------------------------------------------------------
class MinimapView(context: android.content.Context) :
    TextureView(context), TextureView.SurfaceTextureListener {

    /** Direct reference to the hosting MainActivity for cross-context callbacks. */
    var mainActivity: MainActivity? = null

    /**
     * Parent FrameLayout that carries the LAYER_TYPE_HARDWARE ColorMatrix filter.
     * Set by MainActivity.setupHud() immediately after creating the view.
     * onSurfaceTextureUpdated() calls filterWrapper.invalidate() so the hardware
     * layer re-renders each YNavi frame (TextureView updates bypass View.invalidate).
     */
    var filterWrapper: FrameLayout? = null

    @Volatile var baseHue: Float = 120f // green-yellow hue
    @Volatile private var running = false
    private var renderThread: Thread? = null

    // Pause/resume lock — the render loop waits here while paused.
    private val pauseLock = Object()
    @Volatile private var paused = false

    /**
     * Set to true when setMinimap(enabled=true) is received but the SurfaceTexture
     * is not yet available. onSurfaceTextureAvailable will call back to start YNavi.
     */
    @Volatile var pendingYNaviStart: Boolean = false

    /** Stop the render loop (called when the minimap is hidden or the HUD engine is torn down).
     *
     * QA4-4: terminates the thread instead of just parking it, so no thread
     * stays alive when the minimap is disabled (ADR 0001 efficiency).
     * resumeRendering() detects renderThread==null and calls startRenderLoop() to restart.
     */
    fun pauseRendering() {
        running = false
        paused  = true
        synchronized(pauseLock) { pauseLock.notifyAll() }  // wake if waiting
        renderThread?.interrupt()
        try { renderThread?.join(500) } catch (_: InterruptedException) {}
        renderThread = null
        Log.i("ZEE", "MinimapView: render loop STOPPED (pauseRendering)")
    }

    /** Resume the render loop (called when the minimap is shown). */
    fun resumeRendering() {
        // GOAL 2: Never resume while YNavi host is active (strict exclusive ownership).
        val host = (context as? MainActivity)?.yNaviCarAppHost
        if (host?.isActive == true) {
            Log.w("ZEE", "MinimapView: resumeRendering BLOCKED — YNavi host is ACTIVE (exclusive surface)")
            return
        }
        // Re-apply the hardware layer before the render loop resumes drawing.
        paused = false
        if (!running || renderThread == null) {
            // Thread was stopped by parkForYNavi(); restart it.
            startRenderLoop()
            Log.i("ZEE", "MinimapView: render loop RESUMED (restarted)")
        } else {
            synchronized(pauseLock) { pauseLock.notifyAll() }
            Log.i("ZEE", "MinimapView: render loop RESUMED")
        }
    }

    /**
     * Park the render loop for YNavi surface ownership.
     * Unlike pauseRendering(), this does NOT resume later unless YNavi disconnects.
     *
     * Stops the render thread entirely and removes the LAYER_TYPE_HARDWARE before
     * yielding the surface.  The canvas render loop holds the SurfaceTexture's
     * producer slot with api=2 (CPU), which prevents YNavi from connecting its EGL
     * renderer (api=1).  Without stopping the thread first, YNavi receives the
     * surface but eglCreateWindowSurface fails with "already connected (cur=2 req=1)".
     */
    fun parkForYNavi() {
        Log.i("ZEE", "MinimapView: parkForYNavi ENTER running=$running paused=$paused thread=${renderThread != null}")
        // Stop the render thread so it releases any api=2 (Canvas) producer hold.
        running = false
        paused = true  // belt-and-suspenders: prevent re-entry if loop re-checks
        synchronized(pauseLock) { pauseLock.notifyAll() }  // wake if waiting
        renderThread?.interrupt()
        try {
            // Block until the render thread actually exits (max 500ms timeout).
            renderThread?.join(500)
        } catch (_: InterruptedException) {}
        renderThread = null
        // CRITICAL: Signal YNavi start for when the surface becomes available.
        // This is set BEFORE the detach/re-attach so it is in place when
        // onSurfaceTextureAvailable fires on the re-attach.
        pendingYNaviStart = true
        // Disconnect api=2 by forcing a full TextureView lifecycle cycle:
        //   removeView()  → onDetachedFromWindow()  → mSurface.release()
        //                   (api=2 producer slot on old SurfaceTexture is freed)
        //   addView()     → onAttachedToWindow()  → new hardware layer created
        //                 → new GL-attached SurfaceTexture allocated internally
        //                 → onSurfaceTextureAvailable() fires
        //                 → startYNaviOnSurfaceReady() → host.start(Surface(newSt), …)
        //
        // SurfaceTexture(false) (detached mode) does NOT work: GL attachment is
        // asynchronous and producers fail with
        // "SurfaceTexture is not attached to a View" until it completes.
        // setSurfaceTexture() with LAYER_TYPE_NONE also fails: mLayer is destroyed
        // before the swap so mLayer.setSurfaceTexture(freshSt) is never called.
        val pg = parent as? ViewGroup
        if (pg != null) {
            val idx = pg.indexOfChild(this)
            val lp = layoutParams
            pg.removeView(this)         // onDetachedFromWindow → mSurface.release()
            pg.post { pg.addView(this, idx, lp) }  // re-attach → fresh GL-attached SurfaceTexture
            Log.i("ZEE", "MinimapView: render loop PARKED (thread exited; view detached for fresh GL-attached SurfaceTexture)")
        } else {
            Log.w("ZEE", "MinimapView: parkForYNavi — no parent ViewGroup; pendingYNaviStart=true only")
            Log.i("ZEE", "MinimapView: render loop PARKED (thread exited; no parent, YNavi start deferred)")
        }
    }

    init {
        // isOpaque=false: the TextureView does not need to claim it fills all pixels;
        // the filterWrapper parent's hardware layer handles compositing.
        isOpaque = false
        surfaceTextureListener = this
        // Filter is applied by filterWrapper (FrameLayout parent) via LAYER_TYPE_HARDWARE.
        // Setting it on the TextureView directly does NOT filter SurfaceTexture content
        // from YNavi's EGL renderer — the wrapper pattern is mandatory (hud-presentation-host.md §7).
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        if (pendingYNaviStart) {
            pendingYNaviStart = false
            // Delegate to MainActivity to start the YNavi host on the main thread.
            (mainActivity ?: context as? MainActivity)?.startYNaviOnSurfaceReady(surface, width, height)
                ?: run {
                    // Fallback: no activity reference (e.g. Presentation context);
                    // start the placeholder instead.
                    startRenderLoop()
                }
        } else {
            startRenderLoop()
        }
    }

    private fun startRenderLoop() {
        running = true
        renderThread = Thread {
            var phase = 0f
            while (running) {
                // Pause gate: park here while the minimap is hidden or YNavi owns the surface.
                if (paused) {
                    synchronized(pauseLock) {
                        while (paused && running) {
                            try { pauseLock.wait() } catch (_: InterruptedException) { break }
                        }
                    }
                    if (!running) break
                }
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
                    // Notify the parent hardware layer that a new placeholder frame is
                    // ready. TextureView's own invalidation does not propagate through a
                    // LAYER_TYPE_HARDWARE parent (same staleness reason as onSurfaceTextureUpdated).
                    filterWrapper?.postInvalidate()
                }
                try { Thread.sleep(33) } catch (_: InterruptedException) { break }  // ~30fps placeholder (QA4-6)
            }
        }.also { it.start() }
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        running = false
        synchronized(pauseLock) { pauseLock.notifyAll() }  // wake if paused
        renderThread?.interrupt()
        renderThread = null
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
        // Hardware layer on filterWrapper caches its output; TextureView SurfaceTexture
        // updates bypass View.invalidate(), so the cached layer goes stale without
        // this explicit call. Matches phase0 onSurfaceTextureUpdated pattern (§7 doc).
        filterWrapper?.invalidate()
    }
}

package com.zeepowertoys.zee_power_toys

import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.zeepowertoys.zee_power_toys.boot.BootRemediation
import com.zeepowertoys.zee_power_toys.boot.ConfigShim
import com.zeepowertoys.zee_power_toys.boot.ZeeForegroundService
import com.zeepowertoys.zee_power_toys.carapp.YNaviCarAppHost
import com.zeepowertoys.zee_power_toys.carsignals.CarSignalsController
import com.zeepowertoys.zee_power_toys.carsignals.SimulateReceiver
import com.zeepowertoys.zee_power_toys.install.InstallerController
import com.zeepowertoys.zee_power_toys.install.PackageStatusController
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
//   parametric ColorMatrix filter) UNDER a transparent FlutterTextureView overlay.
//   The zee/minimap MethodChannel is registered on the DHU engine (primary) so
//   the DHU Dart isolate drives the native Minimap surface.
//
//   MinimapView carries NO placeholder content of its own (the animated rainbow
//   gradient render thread was removed — it violated the emissive-black-only
//   HUD rule when YNavi was absent). Availability is gated natively, in
//   setMinimap(): when YNavi is not installed/detectable the view is left/set
//   INVISIBLE and "unavailable" is returned to Dart — Dart's own enable(true)
//   call can never single-handedly put content on the surface.
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ZEE"
        /** Zeekr DHU windshield optics — same as phase0 HUD_DISPLAY_ID. */
        private const val HUD_DISPLAY_ID = 2
        private const val HUB_CHANNEL = "zee/hub"
        private const val MINIMAP_CHANNEL = "zee/minimap"
        private const val MINIMAP_GUIDANCE_CHANNEL = "zee/minimap/guidance"
        private const val SPEEDCAM_LOCATION_CHANNEL = "zee/speedcam/location"
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
    private var packageStatusController: PackageStatusController? = null

    // SystemConfig native bridge — DHU engine only (Block 0015).
    private var systemConfigController: SystemConfigController? = null

    // UsbMode native bridge — DHU engine only (Block 0016).
    private var usbModeController: UsbModeController? = null

    // Minimap native surface — created in setupHud; driven via zee/minimap channel.
    private var minimapView: MinimapView? = null

    // Mutable filter + zoom parameters — single source of truth for the HUD
    // ColorMatrix paint and the YNavi oversample/dpi levers. Rebuilt into a
    // fresh Paint by applyFilter() / a fresh surface config by
    // resizeYNaviSurface() on every setMinimapParam call — no rebuild, no
    // re-bind required to retune (Task 2).
    private var minimapParams = MinimapParams()

    // YNavi CarApp host — binds to YNavi and feeds the MinimapView surface.
    // Null when YNavi is unavailable or the minimap is disabled.
    // Internal visibility so MinimapView can check isActive for exclusive surface ownership.
    internal var yNaviCarAppHost: YNaviCarAppHost? = null

    // Guidance EventChannel sink — set when Dart subscribes to zee/minimap/guidance.
    @Volatile private var guidanceSink: EventChannel.EventSink? = null
    // Speedcam location EventChannel sink — YNavi sendLocation → Dart setHostPose.
    @Volatile private var speedcamLocationSink: EventChannel.EventSink? = null

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

        // YNavi IAppHost.sendLocation → Dart Speedcam host pose (0050).
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEEDCAM_LOCATION_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    speedcamLocationSink = sink
                    Log.i(TAG, "speedcam location EventChannel: Dart subscribed")
                }
                override fun onCancel(arguments: Any?) {
                    speedcamLocationSink = null
                    Log.i(TAG, "speedcam location EventChannel: Dart unsubscribed")
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
                    // Manual silent YNavi restart (phase0 RESTART_YNAVI_SILENT).
                    "restartYNavi" -> {
                        val ok = BootRemediation.restartYNaviSilent(applicationContext)
                        result.success(mapOf("ok" to ok))
                    }
                    "pushClusterLocaleEnglish" -> {
                        Thread {
                            val ok = BootRemediation.pushClusterLocaleEnglish(applicationContext)
                            runOnUiThread {
                                result.success(mapOf("ok" to ok))
                            }
                        }.start()
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
        packageStatusController = PackageStatusController(this, flutterEngine.dartExecutor.binaryMessenger)

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
                "Run: adb shell settings put global overlay_display_devices \"1024x576/213\"")
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
            applyFilter()
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
                // Native gate (Task 1), async half: if the bind itself fails despite
                // isYnaviAvailable() passing its static check, force the surface back
                // dark rather than leaving it VISIBLE with nothing ever drawn into it.
                host.onBindFailed = {
                    minimapView?.visibility = View.INVISIBLE
                    Log.w(TAG, "YNavi bind failed — MinimapView forced INVISIBLE")
                }
                host.onLocation = { loc ->
                    val speedKmh = if (loc.hasSpeed()) loc.speed * 3.6 else null
                    val heading = if (loc.hasBearing()) loc.bearing.toDouble() else null
                    val event = hashMapOf<String, Any?>(
                        "lat" to loc.latitude,
                        "lon" to loc.longitude,
                        "source" to "ynavi",
                    )
                    if (speedKmh != null) event["speedKmh"] = speedKmh
                    if (heading != null) event["headingDeg"] = heading
                    speedcamLocationSink?.success(event)
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
            // displayId is included (Block 0027) so the Feedback Loop's readViewModel
            // can report which logical display `adb exec-out screencap -d <id>` must
            // target for the native composite capture — the app is the source of
            // truth for its own HUD geometry, not a Python reimplementation of it.
            val hudDm = DisplayMetrics().also { display.getMetrics(it) }
            dhuMinimapChannel?.invokeMethod(
                "hudReady",
                mapOf(
                    "w" to hudDm.widthPixels,
                    "h" to hudDm.heightPixels,
                    "dpi" to hudDm.densityDpi,
                    "displayId" to display.displayId,
                )
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
    // HUD filter + zoom parameters — single mutable holder (Task 2).
    //
    // History of this default within the Block (all three measured on T2, not
    // guessed):
    //
    // 1. White(2)/hueAngle=290/threshold=150 — phase0's documented numbers,
    //    ported verbatim. REJECTED: leaves a visible navy background glow.
    //    hueAngle=290 sits between two ColorMatrix primaries (240/blue,
    //    0/red), so the hue-passthrough formula below gives BOTH the R and B
    //    rows a large fractional identity-contrast weight instead of cleanly
    //    zeroing one of them — the background never fully crushes.
    // 2. White(2)/hueAngle=290/threshold=225 — raising threshold crushed the
    //    glow to genuine black, but the surviving roads render as dim navy.
    //    On an emissive projector dim-blue reads as near-invisible, not a
    //    "mark" — REJECTED for insufficient brightness, even though the
    //    background-black part of the fix was correct and is kept below.
    // 3. Green(0)/hueAngle=120/huePass=1.0, threshold swept 150-245 —
    //    REJECTED: this build's YNavi night-theme road colour is blue, not
    //    green, so there is no strong green content to rescue. Depending on
    //    threshold this either floods bright green over unrelated green
    //    polygon fills (parks — huePass doesn't distinguish "a road that
    //    happens to be green" from "a park that happens to be green") at low
    //    threshold, or crushes the (non-green) roads into invisibility along
    //    with the background at high threshold. Content-dependent and never
    //    hits "black background AND bright roads" simultaneously in testing.
    // 4. Green(0)/huePass=0.0 (hue-passthrough OFF), contrast=3.5,
    //    threshold=165 — THE FIX. huePass=0 means hueAngle is irrelevant: the
    //    whole image becomes a pure monochrome-tint threshold render (uniform
    //    green-yellow tint on whatever survives contrast+threshold), so it
    //    no longer depends on matching the source content's real hue at all
    //    — sidesteps the wrong-dominant-colour and park-flooding problems
    //    from options 1-3 entirely. Matches the character of the known-good
    //    `shots/redo/t2-hud-final-readable.png` reference. Measured
    //    blackFrac=0.9255 (target was >=0.80) with unmistakably bright neon
    //    green roads/labels, confirmed by eye.
    // -------------------------------------------------------------------------
    data class MinimapParams(
        var contrast: Float = 3.5f,
        var threshold: Int = 165,
        var preset: Int = 0,        // 0=green-yellow (default), 1=cyan, 2=white, 3=amber, 4=red
        var saturation: Float = 0f,
        var brightness: Int = -20,
        var invert: Boolean = false,
        // 0.0 = hue-passthrough OFF (pure monochrome tint) — see history
        // above for why this, not a nonzero value, is the correct default.
        var huePass: Float = 0.0f,
        var hueAngle: Int = 120,   // irrelevant while huePass=0.0; kept as the
                                   // green-yellow axis in case huePass is ever
                                   // raised again for a specific hue rescue.
        // Oversample factor: SurfaceTexture buffer is viewport-size × bufScale;
        // measured to affect render resolution/AA only — NOT the geographic
        // area YNavi shows (see resizeYNaviSurface doc). Left at phase0's
        // value; raising it further showed no additional benefit in testing.
        var bufScale: Float = 2.0f, // legacy; prefer minimapScale (phase0)
        // Phase0 HudSettings.minimapScale — buffer = viewport / scale.
        // Default 0.5 → 2× buffer (more map in the same square).
        var minimapScale: Float = 0.5f,
        // Multiplier on the dpi reported to YNavi's SurfaceContainer.
        // Measured across 0.8x-4.0x (both via live resizeYNaviSurface() calls
        // AND via a full stop/start cold-bind so a fresh onSurfaceAvailable
        // is guaranteed): no observable zoom effect at any point in that
        // range on this build. Left at neutral 1.0 — see MainActivity.kt's
        // resizeYNaviSurface doc and the Block's report for the full
        // measurement writeup; this is NOT a working zoom-out lever here.
        var dpiScale: Float = 1.0f,
    )

    // -------------------------------------------------------------------------
    // HUD filter — parametric ColorMatrix with hue passthrough.
    // Ported from phase0 CarAppHostService.createHudFilterPaint (hud-presentation-host.md §7).
    // threshold maps pixels darker than ~threshold/255 to BLACK → dark emissive background.
    // huePass + hueAngle keeps only the chosen hue in colour; all else → mono.
    // -------------------------------------------------------------------------

    private fun createHudFilterPaint(p: MinimapParams): Paint {
        val (tR, tG, tB) = when (p.preset) {
            1 -> Triple(0.1f, 0.9f, 1.0f)    // cyan
            2 -> Triple(1.0f, 1.0f, 1.0f)    // white
            3 -> Triple(1.0f, 0.75f, 0.0f)   // amber
            4 -> Triple(1.0f, 0.15f, 0.0f)   // red
            else -> Triple(0.7f, 1.0f, 0.1f) // green-yellow (preset=0)
        }
        val c = p.contrast
        val t = -p.threshold.toFloat()
        val s = p.saturation.coerceIn(0f, 1f)
        val ms = 1f - s   // monochrome weight
        val b = p.brightness.toFloat()
        val hp = p.huePass.coerceIn(0f, 1f)
        val lr = 0.3f; val lg = 0.6f; val lb = 0.1f

        // Base coefficients per output channel (monochrome-tint + saturation blend).
        val rR = ms * lr * c * tR + s * c;  val rG_r = ms * lg * c * tR;          val rB_r = ms * lb * c * tR
        val gR = ms * lr * c * tG;          val gG = ms * lg * c * tG + s * c;    val gB_g = ms * lb * c * tG
        val bR = ms * lr * c * tB;          val bG_b = ms * lg * c * tB;          val bB = ms * lb * c * tB + s * c
        val rOff = ms * t * tR + s * t + b
        val gOff = ms * t * tG + s * t + b
        val bOff = ms * t * tB + s * t + b

        // Per-channel hue passthrough: triangle peaking at each channel's primary hue
        // (R=0°, G=120°, B=240°), 120° half-width.  At huePass=1.0 the row for the
        // channel nearest hueAngle is replaced by identity-contrast, keeping that
        // hue's map features in colour while the dark background is zeroed by
        // the threshold.
        val angle = (p.hueAngle % 360).toFloat()
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

        if (p.invert) {
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

    /**
     * Rebuild the ColorMatrix Paint from the current [minimapParams] and re-apply
     * it to filterWrapper's hardware layer. This is the entire "retune without a
     * rebuild" path for the filter-affecting params (Task 2): no new Paint object
     * identity is needed elsewhere, no surface renegotiation — just a fresh
     * LAYER_TYPE_HARDWARE paint + invalidate.
     */
    private fun applyFilter() {
        val fw = minimapView?.filterWrapper ?: return
        fw.setLayerType(View.LAYER_TYPE_HARDWARE, createHudFilterPaint(minimapParams))
        fw.invalidate()
    }

    /**
     * Re-negotiate the YNavi surface's buffer size + reported dpi from the
     * current [minimapParams] zoom levers (or explicit overrides). This is the
     * fix for the live bug where setMinimapBounds resized the filterWrapper but
     * left YNavi rendering into a stale buffer (YNaviCarAppHost.updateSurface
     * had zero callers before this Block). NOOP when no YNavi host is active —
     * the levers still take effect the next time start() runs.
     *
     * Known limitation (measured, not fixed in this Block): this goes through
     * [YNaviCarAppHost.updateSurface] -> [IAppHostStub.onSurfaceReady], which
     * re-dispatches `ISurfaceCallback.onSurfaceAvailable` — the SAME callback
     * as the original bind, not the CarApp library's `onSurfaceChanged`. A
     * well-behaved SurfaceCallback consumer expects `onSurfaceAvailable`
     * exactly once per surface lifetime, so a second call may be silently
     * ignored. Measured effect: sweeping bufScale/dpiScale over a wide range
     * via this path (and even via a full stop()/start() cold rebind, which
     * DOES call onSurfaceAvailable exactly once for a fresh session) produced
     * no visible zoom change on this build — see the Block's report. Fixing
     * this for real would mean adding a genuine `onSurfaceChanged` dispatch to
     * IAppHostStub/ICarHostStub; out of scope here since the dpi/buf levers
     * were not shown to control zoom at all, cold-start included.
     */

    /** Phase0 buffer size: viewport / minimapScale (scale in 0.25..1). */
    private fun bufferSizeForViewport(viewportW: Int, viewportH: Int): Pair<Int, Int> {
        val scale = minimapParams.minimapScale.coerceIn(0.25f, 1.0f)
        return if (scale < 1.0f) {
            Pair(
                (viewportW / scale).toInt().coerceAtLeast(1),
                (viewportH / scale).toInt().coerceAtLeast(1),
            )
        } else {
            Pair(viewportW.coerceAtLeast(1), viewportH.coerceAtLeast(1))
        }
    }

    private fun resizeYNaviSurface(
        viewportW: Int,
        viewportH: Int,
        bufWOverride: Int? = null,
        bufHOverride: Int? = null,
        dpiOverride: Int? = null,
    ) {
        val v = minimapView ?: return
        val host = yNaviCarAppHost
        if (host == null || !host.isActive) {
            Log.i(TAG, "resizeYNaviSurface: no active YNavi host — skip (viewport=${viewportW}x$viewportH)")
            return
        }
        val st = v.surfaceTexture
        if (st == null) {
            Log.w(TAG, "resizeYNaviSurface: no SurfaceTexture yet — skip")
            return
        }
        val (computedW, computedH) = bufferSizeForViewport(viewportW, viewportH)
        val bufW = (bufWOverride ?: computedW).coerceAtLeast(1)
        val bufH = (bufHOverride ?: computedH).coerceAtLeast(1)
        val dpi = (dpiOverride ?: (hudDensityDpi() * minimapParams.dpiScale).toInt()).coerceAtLeast(1)
        st.setDefaultBufferSize(bufW, bufH)
        host.updateSurface(Surface(st), bufW, bufH, dpi)
        Log.i(TAG, "resizeYNaviSurface: buf=${bufW}x${bufH} dpi=$dpi viewport=${viewportW}x$viewportH")
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
                    if (enabled) {
                        // Native availability gate (Task 1): this is the ONLY place that
                        // decides whether the surface may show content. Dart's enable(true)
                        // alone can never bypass it — ext.zee.minimap calls through here too.
                        val host = yNaviCarAppHost
                        val available = host != null && isYnaviAvailable()
                        if (!available) {
                            if (v.visibility != View.INVISIBLE) v.visibility = View.INVISIBLE
                            Log.i(TAG, "setMinimap(true): YNavi unavailable — native gate APPLIED, view INVISIBLE")
                            result.success("unavailable")
                            return@post
                        }
                        if (v.visibility != View.VISIBLE) v.visibility = View.VISIBLE
                        if (host!!.isActive) {
                            // YNavi already hosting — nothing to (re)start.
                            Log.i(TAG, "setMinimap(true): YNavi host already active — NOOP")
                        } else {
                            // Hand the MinimapView surface over to YNavi.
                            // parkForYNavi() removes/re-adds the view to trigger a full
                            // TextureView lifecycle cycle that frees any stale producer and
                            // creates a fresh GL-attached SurfaceTexture.  host.start() is
                            // called from startYNaviOnSurfaceReady() when
                            // onSurfaceTextureAvailable fires — NOT here.
                            v.parkForYNavi()
                            Log.i(TAG, "setMinimap(true): parkForYNavi called — YNavi start deferred to onSurfaceTextureAvailable")
                        }
                        Log.i(TAG, "setMinimap(true): APPLIED")
                        result.success("applied:true")
                    } else {
                        if (v.visibility != View.INVISIBLE) v.visibility = View.INVISIBLE
                        val host = yNaviCarAppHost
                        if (host != null && host.isActive) {
                            host.stop()
                            Log.i(TAG, "setMinimap(false): YNavi host stopped")
                        }
                        v.pendingYNaviStart = false
                        Log.i(TAG, "setMinimap(false): APPLIED")
                        result.success("applied:false")
                    }
                }
                "setMinimapBounds" -> {
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    val w = call.argument<Int>("w") ?: FrameLayout.LayoutParams.MATCH_PARENT
                    val h = call.argument<Int>("h") ?: FrameLayout.LayoutParams.MATCH_PARENT
                    // Optional explicit overrides for the YNavi buffer/dpi — normally
                    // omitted, in which case they are derived from minimapParams
                    // (bufScale/dpiScale) × the new viewport size.
                    val bufW = (call.argument<Any?>("bufW") as? Number)?.toInt()
                    val bufH = (call.argument<Any?>("bufH") as? Number)?.toInt()
                    val dpiArg = (call.argument<Any?>("dpi") as? Number)?.toInt()
                    // Phase0 model (hud-presentation-host.md §5): size the filterWrapper
                    // to the viewport rect, NOT the MinimapView.  The filterWrapper carries
                    // the LAYER_TYPE_HARDWARE ColorMatrix filter; sizing it to the square
                    // confines both the YNavi map surface and the colour filter to the
                    // viewport.  The MinimapView remains MATCH_PARENT inside filterWrapper.
                    val fw = v.filterWrapper
                    if (fw != null) {
                        fw.layoutParams = FrameLayout.LayoutParams(w, h).apply {
                            leftMargin = x
                            topMargin  = y
                            gravity    = Gravity.TOP or Gravity.START
                        }
                        fw.requestLayout()
                        Log.i(TAG, "setMinimapBounds($x,$y,$w,$h): filterWrapper SIZED")
                    } else {
                        Log.w(TAG, "setMinimapBounds($x,$y,$w,$h): filterWrapper null — fallback on MinimapView")
                        v.layoutParams = FrameLayout.LayoutParams(w, h).apply {
                            leftMargin = x; topMargin = y
                        }
                        v.requestLayout()
                    }
                    // Live-bug fix: a bounds change (e.g. preset switch) must re-negotiate
                    // the YNavi surface too, or YNavi keeps rendering into a stale buffer
                    // sized for the OLD viewport (updateSurface previously had zero callers).
                    resizeYNaviSurface(w, h, bufW, bufH, dpiArg)
                    result.success("bounds:$x,$y,$w,$h")
                }
                "setMinimapParam" -> {
                    val key = call.argument<String>("key") ?: ""
                    val raw = call.argument<Any?>("value")
                    fun asFloat(): Float? = when (raw) {
                        is Number -> raw.toFloat()
                        is String -> raw.toFloatOrNull()
                        else -> null
                    }
                    fun asInt(): Int? = when (raw) {
                        is Number -> raw.toInt()
                        is String -> raw.toIntOrNull() ?: raw.toFloatOrNull()?.toInt()
                        else -> null
                    }
                    fun asBool(): Boolean? = when (raw) {
                        is Boolean -> raw
                        is Number -> raw.toInt() != 0
                        is String -> raw.toBooleanStrictOrNull() ?: (raw == "1")
                        else -> null
                    }
                    // preset also accepts a name (driving convenience: `minimap key=preset value=white`).
                    fun presetIndexFromName(): Int? = (raw as? String)?.lowercase()?.let {
                        when (it) {
                            "green", "green-yellow", "greenyellow" -> 0
                            "cyan" -> 1
                            "white" -> 2
                            "amber" -> 3
                            "red" -> 4
                            else -> null
                        }
                    }
                    var recognized = true
                    when (key) {
                        "contrast"   -> asFloat()?.let { minimapParams.contrast = it }
                        "threshold"  -> asInt()?.let { minimapParams.threshold = it }
                        "preset"     -> (asInt() ?: presetIndexFromName())?.let { minimapParams.preset = it }
                        "saturation" -> asFloat()?.let { minimapParams.saturation = it }
                        "brightness" -> asInt()?.let { minimapParams.brightness = it }
                        "invert"     -> asBool()?.let { minimapParams.invert = it }
                        "huePass"    -> asFloat()?.let { minimapParams.huePass = it }
                        "hueAngle"   -> asInt()?.let { minimapParams.hueAngle = it }
                        "bufScale"   -> asFloat()?.let {
                            // Legacy: bufScale 2.0 ≡ minimapScale 0.5
                            minimapParams.bufScale = it
                            if (it > 0f) minimapParams.minimapScale = (1f / it).coerceIn(0.25f, 1.0f)
                        }
                        "minimapScale" -> asFloat()?.let {
                            minimapParams.minimapScale = it.coerceIn(0.25f, 1.0f)
                            minimapParams.bufScale = 1f / minimapParams.minimapScale
                        }
                        "dpiScale"   -> asFloat()?.let { minimapParams.dpiScale = it }
                        else -> recognized = false
                    }
                    if (!recognized) {
                        Log.i(TAG, "setMinimapParam($key): ignored")
                        result.success("ignored:$key")
                        return@post
                    }
                    when (key) {
                        "bufScale", "minimapScale", "dpiScale" -> {
                            // Cold rebind — resizeYNaviSurface alone does not change
                            // geographic zoom on this YNavi build (onSurfaceAvailable
                            // re-dispatch is ignored). Stop + parkForYNavi forces a
                            // fresh SurfaceTexture and start() with new buffer size.
                            val host = yNaviCarAppHost
                            if (host != null && host.isActive) {
                                host.stop()
                                v.parkForYNavi()
                                Log.i(TAG, "setMinimapParam($key): cold rebind via parkForYNavi scale=${minimapParams.minimapScale}")
                            } else {
                                resizeYNaviSurface(v.width, v.height)
                            }
                        }
                        else -> applyFilter()
                    }
                    Log.i(TAG, "setMinimapParam($key=$raw): APPLIED -> $minimapParams")
                    result.success("applied:$key")
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
            // Oversample the buffer by minimapParams.bufScale: tells YNavi to render
            // a larger map area which the compositor scales down to viewport size.
            // dpiScale is the crisper zoom lever — it changes ground-per-pixel at
            // YNavi's render time instead of just downscaling the oversampled bitmap
            // (Task 2/Task 3 — see MinimapParams doc for the measured defaults).
            val dpi = (hudDensityDpi() * minimapParams.dpiScale).toInt().coerceAtLeast(1)
            val (bufW, bufH) = bufferSizeForViewport(width, height)
            surface.setDefaultBufferSize(bufW, bufH)
            host.start(Surface(surface), bufW, bufH, dpi)
            Log.i(TAG, "startYNaviOnSurfaceReady: YNavi host started w=$width h=$height buf=${bufW}x${bufH} scale=${minimapParams.minimapScale} dpi=$dpi")
        } else {
            // Native gate (Task 1): this path should not normally be reached —
            // setMinimap() already refuses to parkForYNavi() when YNavi is
            // unavailable — but defensively keep the view dark rather than
            // falling back to the removed placeholder render loop.
            minimapView?.visibility = View.INVISIBLE
            Log.i(TAG, "startYNaviOnSurfaceReady: YNavi unavailable — view kept INVISIBLE (no placeholder)")
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
    // Display discovery — match phase0 (zee_hud_2) selectHudDisplay:
    // prefer displayId=2 (Zeekr optics), then PRESENTATION category, then any
    // non-default (T2 emulator overlay_display_devices usually has one secondary).
    // -------------------------------------------------------------------------

    private fun findSecondaryDisplay(): Display? {
        val dm = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = dm.displays
        Log.i(TAG, "findSecondaryDisplay: ${displays.size} display(s): " +
            displays.joinToString { "[id=${it.displayId} name=${it.name} " +
                "size=${it.mode?.physicalWidth}x${it.mode?.physicalHeight}]" })
        val picked = displays.firstOrNull { it.displayId == HUD_DISPLAY_ID }
            ?: dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull()
            ?: displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
        Log.i(TAG, "findSecondaryDisplay: picked id=${picked?.displayId} name=${picked?.name}")
        return picked
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
// MinimapView — native TextureView hosting the YNavi map under-layer.
//
// Carries NO content of its own: it is a pure surface handed to YNavi's EGL
// renderer. (Until this Block it drew an animated rainbow-gradient placeholder
// on a dedicated render thread — that violated the emissive-black-only HUD
// rule whenever YNavi was absent, and was deleted along with the render
// thread, its sleep-based frame pacing, and resumeRendering()/pauseRendering(). The native
// availability gate now lives entirely in MainActivity.handleMinimap's
// setMinimap branch: when YNavi is unavailable the view is simply left/set
// INVISIBLE and no SurfaceTexture content is ever produced.)
//
// The parametric HUD ColorMatrix filter is applied on filterWrapper (the
// FrameLayout parent), never on this TextureView directly — setLayerType on
// the TextureView itself does NOT filter SurfaceTexture content from an
// external EGL renderer (hud-presentation-host.md §7).
//
//   pendingYNaviStart: set true by parkForYNavi() before the detach/re-attach
//     cycle; onSurfaceTextureAvailable calls back to MainActivity to start
//     the YNavi host once the fresh GL-attached SurfaceTexture exists.
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

    /**
     * Set to true when setMinimap(enabled=true) is received but the SurfaceTexture
     * is not yet available. onSurfaceTextureAvailable will call back to start YNavi.
     */
    @Volatile var pendingYNaviStart: Boolean = false

    /**
     * Force a full TextureView lifecycle cycle (detach/re-attach) so YNavi gets a
     * fresh GL-attached SurfaceTexture. Load-bearing: without this cycle a stale
     * producer can be left on the old SurfaceTexture and YNavi's
     * eglCreateWindowSurface fails with "already connected (cur=2 req=1)".
     */
    fun parkForYNavi() {
        Log.i("ZEE", "MinimapView: parkForYNavi ENTER")
        // CRITICAL: Signal YNavi start for when the surface becomes available.
        // This is set BEFORE the detach/re-attach so it is in place when
        // onSurfaceTextureAvailable fires on the re-attach.
        pendingYNaviStart = true
        //   removeView()  → onDetachedFromWindow()  → mSurface.release()
        //   addView()     → onAttachedToWindow()  → new hardware layer created
        //                 → new GL-attached SurfaceTexture allocated internally
        //                 → onSurfaceTextureAvailable() fires
        //                 → startYNaviOnSurfaceReady() → host.start(Surface(newSt), …)
        //
        // SurfaceTexture(false) (detached mode) does NOT work: GL attachment is
        // asynchronous and producers fail with
        // "SurfaceTexture is not attached to a View" until it completes.
        val pg = parent as? ViewGroup
        if (pg != null) {
            val idx = pg.indexOfChild(this)
            val lp = layoutParams
            pg.removeView(this)         // onDetachedFromWindow → mSurface.release()
            pg.post { pg.addView(this, idx, lp) }  // re-attach → fresh GL-attached SurfaceTexture
            Log.i("ZEE", "MinimapView: parkForYNavi — view detached for fresh GL-attached SurfaceTexture")
        } else {
            Log.w("ZEE", "MinimapView: parkForYNavi — no parent ViewGroup; pendingYNaviStart=true only")
        }
    }

    init {
        // isOpaque=false: the TextureView does not need to claim it fills all pixels;
        // the filterWrapper parent's hardware layer handles compositing.
        isOpaque = false
        surfaceTextureListener = this
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        if (pendingYNaviStart) {
            pendingYNaviStart = false
            // Delegate to MainActivity to start the YNavi host on the main thread.
            (mainActivity ?: context as? MainActivity)?.startYNaviOnSurfaceReady(surface, width, height)
        }
        // No placeholder fallback: YNavi absence is gated natively in
        // MainActivity.handleMinimap's setMinimap branch BEFORE parkForYNavi is
        // ever called, so pendingYNaviStart is simply false and this surface is
        // never drawn into — the view stays INVISIBLE, reading as pure black.
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
        // Hardware layer on filterWrapper caches its output; TextureView SurfaceTexture
        // updates bypass View.invalidate(), so the cached layer goes stale without
        // this explicit call. Matches phase0 onSurfaceTextureUpdated pattern (§7 doc).
        filterWrapper?.invalidate()
    }
}

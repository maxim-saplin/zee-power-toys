package com.zeepowertoys.zee_power_toys

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import com.zeepowertoys.zee_power_toys.carsignals.CarSignalsController
import com.zeepowertoys.zee_power_toys.carsignals.SimulateReceiver
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
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
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ZEE"
        private const val HUB_CHANNEL = "zee/hub"
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

        // Construct CarSignalsController on the DHU engine messenger.
        // selectSource() probes AdaptAPI availability and logs the chosen source.
        val ctrl = CarSignalsController(this, flutterEngine.dartExecutor.binaryMessenger)
        ctrl.selectSource()
        carSignalsController = ctrl
        // Expose to SimulateReceiver so ADB broadcasts reach the live source.
        SimulateReceiver.controllerRef = ctrl

        // Defer HUD setup: give the primary view time to attach and render.
        handler.postDelayed({ setupHud() }, HUD_SPAWN_DELAY_MS)
    }

    // -------------------------------------------------------------------------
    // HUD engine setup
    // -------------------------------------------------------------------------

    private fun setupHud() {
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

            // Create the Presentation and attach a FlutterView to the HUD engine.
            val pres = Presentation(this, display)
            val fv = FlutterView(pres.context, FlutterSurfaceView(pres.context))
            pres.setContentView(fv)
            pres.show()
            hudPresentation = pres
            fv.attachToFlutterEngine(eng)
            Log.i(TAG, "setupHud: FlutterView attached to HUD engine; " +
                "isAttached=${fv.isAttachedToFlutterEngine}")
        } catch (t: Throwable) {
            Log.e(TAG, "setupHud: exception during HUD setup", t)
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
        try { hudPresentation?.dismiss() } catch (_: Throwable) {}
        hudEngine?.destroy()
        super.onDestroy()
    }
}

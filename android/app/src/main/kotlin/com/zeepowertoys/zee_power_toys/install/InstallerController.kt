package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * InstallerController — wires Dart ↔ Kotlin for the installer feature (Block 0014).
 *
 * Channels registered on the DHU (primary) engine messenger:
 *   MethodChannel  "zee/installer"         — start(url)
 *   EventChannel   "zee/installer/events"  — install progress stream
 *
 * Flow:
 *   1. Dart calls start() with {url} — a pre-resolved LFS raw-content URL:
 *        https://media.githubusercontent.com/media/<repo>/<branch>/<path>
 *   2. Downloader streams the APK to the app cache directory.
 *   3. Progress events are emitted on the EventChannel:
 *        {phase: "downloading", fraction: 0.0..1.0}
 *        {phase: "installing",  fraction: 0.8}
 *        {phase: "done",        fraction: 1.0}
 *        {phase: "failed",      fraction: 0.0, message: "<error>"}
 *   4. AppInstaller commits a PackageInstaller session (or falls back to
 *      an intent).  The actual install dialog/completion is user-gated (T3).
 *
 * Threading:
 *   Downloads run on a single-thread executor so concurrent start() calls are
 *   serialised.  All EventChannel sink calls are made on the platform thread via
 *   Handler.post to satisfy Flutter's thread-safety requirement.
 */
class InstallerController(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {

    companion object {
        private const val TAG = "ZEE/Installer"
        private const val METHOD_CHANNEL = "zee/installer"
        private const val EVENT_CHANNEL  = "zee/installer/events"
    }

    // Single-thread executor: serialises download/install operations.
    private val executor = Executors.newSingleThreadExecutor()

    // Active EventChannel sink — set when Flutter subscribes, cleared on cancel.
    @Volatile private var eventSink: EventChannel.EventSink? = null

    // Dedup guard (Block 0014 reconciliation): both the "start" method call and
    // the EventChannel onListen trigger startInstall on one Dart invocation; this
    // is the URL currently in flight, so the second trigger is a NOOP.
    @Volatile private var inFlightKey: String? = null

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)

    init {
        // Method channel: start(url) kicks off the download.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isEmpty()) {
                        result.error("BAD_ARGS", "url required", null)
                    } else {
                        // Acknowledge immediately; progress comes on the event stream.
                        result.success(null)
                        startInstall(url)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event channel: the Dart EventChannel.receiveBroadcastStream sends the
        // {url} argument as the listen argument.
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                Log.d(TAG, "EventChannel: Dart subscribed")

                // The Dart side passes the install URL in receiveBroadcastStream.
                // We kick off the download here (the method call "start" above is
                // an alternative trigger — both paths guard against double-start).
                if (arguments is Map<*, *>) {
                    val url = arguments["url"] as? String ?: ""
                    if (url.isNotEmpty()) {
                        startInstall(url)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "EventChannel: Dart unsubscribed")
                eventSink = null
                inFlightKey = null
            }
        })
    }

    /**
     * Kick off the download + install on the background executor.
     *
     * Dedup: a 2nd startInstall call for the same URL while one is already in
     * flight is a NOOP — both the EventChannel onListen and the MethodChannel
     * start() fire startInstall on one Dart invocation; the second trigger hits
     * the key guard and returns immediately.  inFlightKey is cleared when the
     * executor task reaches a terminal state (done or failed), so a later
     * re-install of the same asset is allowed.  Two different assets queue on
     * the single-thread executor.
     *
     * Invariant: inFlightKey is cleared BEFORE Dart is notified of any terminal
     * state so that a re-tap from Dart cannot be wrongly NOOP'd.
     */
    @Synchronized
    private fun startInstall(url: String) {
        if (url == inFlightKey) {
            Log.i(TAG, "startInstall: $url already in flight — NOOP (dedup)")
            return
        }
        inFlightKey = url
        Log.i(TAG, "startInstall: url=$url")
        try {
            executor.submit {
                var terminalPhase = "failed"
                var terminalFraction = 0.0
                var terminalMessage: String? = null
                try {
                    Log.i(TAG, "Resolved URL: $url")

                    val cacheDir = context.cacheDir
                    // Derive a stable cache filename from the last path segment of the URL.
                    val apkName = url.substringAfterLast('/').ifEmpty { "install.apk" }
                    val apkFile = File(cacheDir, apkName)

                    // --- Download phase ---
                    sendProgress("downloading", 0.0)
                    Downloader.download(url, apkFile) { downloaded, total ->
                        val fraction = if (total > 0) {
                            downloaded.toDouble() / total.toDouble()
                        } else {
                            // Unknown Content-Length: pulse at 50 %
                            0.5
                        }
                        sendProgress("downloading", fraction)
                    }
                    Log.i(TAG, "Download complete: ${apkFile.absolutePath} (${apkFile.length()} bytes)")

                    // --- Install phase ---
                    sendProgress("installing", 0.8)
                    try {
                        AppInstaller.installViaSession(context, apkFile)
                        Log.i(TAG, "PackageInstaller session committed")
                    } catch (e: Exception) {
                        // PackageInstaller failed — try intent fallback.
                        Log.w(TAG, "PackageInstaller session failed, trying intent fallback", e)
                        AppInstaller.installViaIntent(context, apkFile)
                    }

                    terminalPhase = "done"
                    terminalFraction = 1.0

                } catch (e: Exception) {
                    Log.e(TAG, "Install error: ${e.message}", e)
                    terminalPhase = "failed"
                    terminalFraction = 0.0
                    terminalMessage = e.message ?: "Unknown error"
                } finally {
                    // Clear inFlightKey BEFORE notifying Dart so a fast re-tap
                    // after 'done' is never wrongly NOOP'd by the dedup guard.
                    inFlightKey = null
                    if (terminalMessage != null) {
                        sendProgress(terminalPhase, terminalFraction, terminalMessage)
                    } else {
                        sendProgress(terminalPhase, terminalFraction)
                    }
                }
            }
        } catch (e: RejectedExecutionException) {
            // Executor was shut down (tearDown called) — release the key so it
            // isn't left permanently stuck.
            Log.w(TAG, "startInstall: executor shut down, releasing key $url", e)
            inFlightKey = null
        }
    }

    /** Send a progress map on the EventChannel (posted to the platform thread). */
    private fun sendProgress(phase: String, fraction: Double, message: String? = null) {
        val map = mutableMapOf<String, Any>(
            "phase" to phase,
            "fraction" to fraction,
        )
        if (message != null) map["message"] = message
        Log.d(TAG, "progress: phase=$phase fraction=$fraction")
        // EventChannel sinks must be called on the platform thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(map)
        }
    }

    /** Tear down channels and executor on Activity destroy. */
    fun tearDown() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        inFlightKey = null
        executor.shutdown()
    }
}

package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * InstallerController — wires Dart ↔ Kotlin for the installer feature (Block 0014).
 *
 * Channels registered on the DHU (primary) engine messenger:
 *   MethodChannel  "zee/installer"         — start(repo, tag, asset)
 *   EventChannel   "zee/installer/events"  — install progress stream
 *
 * Flow:
 *   1. Dart calls start() with {repo, tag, asset}.
 *   2. The native side resolves the GitHub releases download URL:
 *        https://github.com/<repo>/releases/download/<tag>/<asset>
 *   3. Downloader streams the APK to the app cache directory.
 *   4. Progress events are emitted on the EventChannel:
 *        {phase: "downloading", fraction: 0.0..1.0}
 *        {phase: "installing",  fraction: 0.8}
 *        {phase: "done",        fraction: 1.0}
 *        {phase: "failed",      fraction: 0.0, message: "<error>"}
 *   5. AppInstaller commits a PackageInstaller session (or falls back to
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

        // GitHub releases CDN base URL — resolved by Downloader (follows redirects).
        private fun githubUrl(repo: String, tag: String, asset: String): String =
            "https://github.com/$repo/releases/download/$tag/$asset"
    }

    // Single-thread executor: serialises download/install operations.
    private val executor = Executors.newSingleThreadExecutor()

    // Active EventChannel sink — set when Flutter subscribes, cleared on cancel.
    @Volatile private var eventSink: EventChannel.EventSink? = null

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)

    init {
        // Method channel: start(repo, tag, asset) kicks off the download.
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val repo  = call.argument<String>("repo")  ?: ""
                    val tag   = call.argument<String>("tag")   ?: ""
                    val asset = call.argument<String>("asset") ?: ""
                    if (repo.isEmpty() || tag.isEmpty() || asset.isEmpty()) {
                        result.error("BAD_ARGS", "repo/tag/asset required", null)
                    } else {
                        // Acknowledge immediately; progress comes on the event stream.
                        result.success(null)
                        startInstall(repo, tag, asset)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event channel: the Dart EventChannel.receiveBroadcastStream sends the
        // {repo, tag, asset} arguments as the listen arguments.
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                Log.d(TAG, "EventChannel: Dart subscribed")

                // The Dart side passes the install params in receiveBroadcastStream.
                // We kick off the download here (the method call "start" above is
                // an alternative trigger — both paths guard against double-start).
                if (arguments is Map<*, *>) {
                    val repo  = arguments["repo"]  as? String ?: ""
                    val tag   = arguments["tag"]   as? String ?: ""
                    val asset = arguments["asset"] as? String ?: ""
                    if (repo.isNotEmpty() && tag.isNotEmpty() && asset.isNotEmpty()) {
                        startInstall(repo, tag, asset)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "EventChannel: Dart unsubscribed")
                eventSink = null
            }
        })
    }

    /**
     * Kick off the download + install on the background executor.
     *
     * Guard: if an install for the same asset is already running (eventSink is
     * live and the executor queue is non-empty) this call is a no-op.  Two
     * different assets can queue behind each other.
     */
    private fun startInstall(repo: String, tag: String, asset: String) {
        Log.i(TAG, "startInstall: repo=$repo tag=$tag asset=$asset")
        executor.submit {
            try {
                val url = githubUrl(repo, tag, asset)
                Log.i(TAG, "Resolved URL: $url")

                val cacheDir = context.cacheDir
                val apkFile = File(cacheDir, "${asset.removeSuffix(".apk")}_${tag}.apk")

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

                sendProgress("done", 1.0)

            } catch (e: Exception) {
                Log.e(TAG, "Install error: ${e.message}", e)
                sendProgressFailed(e.message ?: "Unknown error")
            }
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

    private fun sendProgressFailed(message: String) {
        sendProgress("failed", 0.0, message)
    }

    /** Tear down channels and executor on Activity destroy. */
    fun tearDown() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
    }
}

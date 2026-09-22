package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicInteger

/**
 * InstallerController — wires Dart ↔ Kotlin for the installer feature (Block 0014).
 *
 * Channels registered on the DHU (primary) engine messenger:
 *   MethodChannel  "zee/installer"         — start(url)
 *   EventChannel   "zee/installer/events"  — install progress stream (multiplexed)
 *
 * Flow:
 *   1. Dart calls start() with {url} — a pre-resolved download URL.
 *   2. Downloader streams the APK to the app cache directory.
 *   3. Progress events are emitted on the EventChannel, each tagged with `url`:
 *        {url, phase: "downloading", fraction: 0.0..1.0}
 *        {url, phase: "installing",  fraction: 1.0}  // after download; UI uses indeterminate
 *        {url, phase: "done",        fraction: 1.0}
 *        {url, phase: "failed",      fraction: 0.0, message: "<error>"}
 *   4. AppInstaller commits a PackageInstaller session (or falls back to
 *      an intent).  The actual install dialog/completion is user-gated (T3).
 *
 * Parallel installs (Block 0084):
 *   Flutter EventChannel allows only one active sink.  A second
 *   receiveBroadcastStream used to cancel the first (onCancel cleared
 *   inFlightKey + stole the sink), so Update looked aborted while its
 *   PackageInstaller session still committed and restarted the app —
 *   progress attributed to the wrong card.
 *   Fix: every event carries `url`; Dart keeps one shared subscription and
 *   fans out by url.  Native tracks a set of in-flight URLs (not a single
 *   key).  onCancel only drops the sink — never aborts jobs.  Downloads run
 *   on a small thread pool.  Self-update commits wait until companion
 *   installs finish so process death does not strand YNavi mid-commit.
 *
 * Threading:
 *   Downloads/installs run on a fixed pool (size 3).  EventChannel sink
 *   calls are posted to the platform thread.
 */
class InstallerController(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {

    companion object {
        private const val TAG = "ZEE/Installer"
        private const val METHOD_CHANNEL = "zee/installer"
        private const val EVENT_CHANNEL  = "zee/installer/events"

        /** Filenames used by 0069 self-update Releases. */
        private val SELF_UPDATE_NAMES = setOf(
            "zee-power-toys.apk",
            "app-release.apk",
        )

        /**
         * True when [url] is a Zee Power Toys self-update APK.
         * Self-update PackageInstaller commit kills this process — defer it
         * until companion installs have finished committing.
         */
        fun isSelfUpdateUrl(url: String): Boolean {
            val name = url.substringAfterLast('/').substringBefore('?')
            if (name in SELF_UPDATE_NAMES) return true
            // browser_download_url may use a different asset name; repo path is stable.
            return url.contains("/maxim-saplin/zee-power-toys/") &&
                name.endsWith(".apk", ignoreCase = true)
        }
    }

    // Parallel download/install slots (0084). Size 3 covers Update + 2 companions.
    private val executor = Executors.newFixedThreadPool(3)

    // Active EventChannel sink — set when Flutter subscribes, cleared on cancel.
    @Volatile private var eventSink: EventChannel.EventSink? = null

    // URLs currently downloading/installing. Dedupes double-start (method+listen).
    private val inFlightUrls: MutableSet<String> =
        Collections.synchronizedSet(mutableSetOf())

    // Companion (non-self-update) jobs still running — self-update waits on this.
    private val companionInFlight = AtomicInteger(0)

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel  = EventChannel(messenger, EVENT_CHANNEL)

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isEmpty()) {
                        result.error("BAD_ARGS", "url required", null)
                    } else {
                        result.success(null)
                        startInstall(url)
                    }
                }
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                Log.d(TAG, "EventChannel: Dart subscribed")

                // Compat: older Dart passed {url} in listen args and also called
                // start().  Shared-subscription Dart (0084) listens with no args
                // and only uses MethodChannel start — so this path is a NOOP then.
                if (arguments is Map<*, *>) {
                    val url = arguments["url"] as? String ?: ""
                    if (url.isNotEmpty()) {
                        startInstall(url)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                // 0084: never clear inFlightUrls here.  A second listen used to
                // cancel the first and wipe the key, aborting Update in the UI
                // while the executor kept going.  Jobs outlive the sink; events
                // are simply dropped until Dart re-subscribes.
                Log.d(TAG, "EventChannel: Dart unsubscribed (jobs keep running)")
                eventSink = null
            }
        })
    }

    /**
     * Kick off download + install on the background pool.
     *
     * Dedup: a 2nd startInstall for a URL already in [inFlightUrls] is a NOOP
     * (method + legacy listen double-fire).  Distinct URLs run concurrently.
     */
    private fun startInstall(url: String) {
        synchronized(inFlightUrls) {
            if (!inFlightUrls.add(url)) {
                Log.i(TAG, "startInstall: $url already in flight — NOOP (dedup)")
                return
            }
        }
        val selfUpdate = isSelfUpdateUrl(url)
        if (!selfUpdate) {
            companionInFlight.incrementAndGet()
        }
        Log.i(TAG, "startInstall: url=$url selfUpdate=$selfUpdate")
        try {
            executor.submit {
                var terminalPhase = "failed"
                var terminalFraction = 0.0
                var terminalMessage: String? = null
                try {
                    Log.i(TAG, "Resolved URL: $url")

                    val cacheDir = context.cacheDir
                    val apkName = url.substringAfterLast('/').substringBefore('?')
                        .ifEmpty { "install.apk" }
                    val apkFile = File(cacheDir, apkName)

                    sendProgress(url, "downloading", 0.0)
                    Downloader.download(url, apkFile) { downloaded, total ->
                        val fraction = if (total > 0) {
                            downloaded.toDouble() / total.toDouble()
                        } else {
                            0.5
                        }
                        sendProgress(url, "downloading", fraction)
                    }
                    Log.i(TAG, "Download complete: ${apkFile.absolutePath} (${apkFile.length()} bytes)")

                    if (selfUpdate) {
                        waitForCompanionsBeforeSelfUpdate(url)
                    }

                    sendProgress(url, "installing", 1.0) // 0086: stay at download-complete; no byte progress
                    try {
                        AppInstaller.installViaSession(context, apkFile)
                        Log.i(TAG, "PackageInstaller session committed for $url")
                    } catch (e: Exception) {
                        Log.w(TAG, "PackageInstaller session failed, trying intent fallback", e)
                        AppInstaller.installViaIntent(context, apkFile)
                    }

                    terminalPhase = "done"
                    terminalFraction = 1.0

                } catch (e: Exception) {
                    Log.e(TAG, "Install error ($url): ${e.message}", e)
                    terminalPhase = "failed"
                    terminalFraction = 0.0
                    terminalMessage = e.message ?: "Unknown error"
                } finally {
                    // Drop from in-flight BEFORE notifying Dart so a fast re-tap
                    // is never wrongly NOOP'd.
                    inFlightUrls.remove(url)
                    if (!selfUpdate) {
                        companionInFlight.decrementAndGet()
                    }
                    if (terminalMessage != null) {
                        sendProgress(url, terminalPhase, terminalFraction, terminalMessage)
                    } else {
                        sendProgress(url, terminalPhase, terminalFraction)
                    }
                }
            }
        } catch (e: RejectedExecutionException) {
            Log.w(TAG, "startInstall: executor shut down, releasing key $url", e)
            inFlightUrls.remove(url)
            if (!selfUpdate) {
                companionInFlight.decrementAndGet()
            }
        }
    }

    /**
     * Block until companion installs leave flight (or timeout).  Prevents
     * self-update PackageInstaller from killing the process before YNavi /
     * launcher sessions are committed.
     */
    private fun waitForCompanionsBeforeSelfUpdate(url: String) {
        val deadline = System.nanoTime() + 10L * 60L * 1_000_000_000L // 10 min
        while (companionInFlight.get() > 0) {
            if (System.nanoTime() > deadline) {
                Log.w(TAG, "self-update $url: timed out waiting for companions; committing anyway")
                return
            }
            Log.i(TAG, "self-update $url: waiting for ${companionInFlight.get()} companion install(s)")
            try {
                Thread.sleep(150)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return
            }
        }
        Log.i(TAG, "self-update $url: companions clear — committing")
    }

    /** Send a progress map on the EventChannel (posted to the platform thread). */
    private fun sendProgress(
        url: String,
        phase: String,
        fraction: Double,
        message: String? = null,
    ) {
        val map = mutableMapOf<String, Any>(
            "url" to url,
            "phase" to phase,
            "fraction" to fraction,
        )
        if (message != null) map["message"] = message
        Log.d(TAG, "progress: url=$url phase=$phase fraction=$fraction")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(map)
        }
    }

    /** Tear down channels and executor on Activity destroy. */
    fun tearDown() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        inFlightUrls.clear()
        companionInFlight.set(0)
        executor.shutdown()
    }
}

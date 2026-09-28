package com.zeepowertoys.zee_power_toys.media

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android [MediaSessionManager] active sessions → Dart now-playing.
 *
 * Channels (DHU engine only — HUD gets snapshots via zee/hub relay):
 *   MethodChannel  "zee/media"         — start() / snapshot()
 *   EventChannel   "zee/media/events"  — streamed now-playing maps
 *
 * Requires [android.permission.MEDIA_CONTENT_CONTROL] (signature|privileged).
 * Zee ships `sharedUserId=android.uid.system` + AOSP platform signing, so this
 * works on dens320 Tablet (platform-signed) and Zeekr DHU. On unprivileged
 * installs [getActiveSessions] throws SecurityException → emit inactive and
 * keep Fake/inject as debug fallback.
 *
 * Progress: position/duration with PLAYING wall-clock adjust; 500 ms ticker
 * while a playing session is active so the HUD bar advances between callbacks.
 */
class MediaSessionController(
    private val ctx: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val TAG = "ZEE"
    private val METHOD_CH = "zee/media"
    private val EVENT_CH = "zee/media/events"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CH)
    private val eventChannel = EventChannel(messenger, EVENT_CH)

    private var eventSink: EventChannel.EventSink? = null
    private var started = false
    private var sessionMgr: MediaSessionManager? = null
    private var activeController: MediaController? = null
    private var lastPayload: Map<String, Any?> = inactivePayload()

    private val controllerCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            emitFromController(activeController)
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            emitFromController(activeController)
            armOrCancelTicker()
        }

        override fun onSessionDestroyed() {
            Log.i(TAG, "MediaSession: session destroyed")
            detachController()
            refreshActiveSession()
        }
    }

    private val sessionsChangedListener =
        MediaSessionManager.OnActiveSessionsChangedListener { _ ->
            refreshActiveSession()
        }

    private val progressTicker = object : Runnable {
        override fun run() {
            val c = activeController
            if (c != null && isPlaying(c.playbackState)) {
                emitFromController(c)
                mainHandler.postDelayed(this, TICK_MS)
            }
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                Log.i(TAG, "MediaSession EventChannel: Dart listening")
                eventSink = sink
                sink.success(lastPayload)
            }

            override fun onCancel(arguments: Any?) {
                Log.i(TAG, "MediaSession EventChannel: Dart unsubscribed")
                eventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                start()
                result.success(lastPayload)
            }
            "snapshot" -> result.success(lastPayload)
            else -> result.notImplemented()
        }
    }

    fun start() {
        if (started) {
            refreshActiveSession()
            return
        }
        started = true
        try {
            val mgr = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            sessionMgr = mgr
            // null ComponentName allowed with MEDIA_CONTENT_CONTROL (system/platform).
            mgr.addOnActiveSessionsChangedListener(
                sessionsChangedListener,
                null as ComponentName?,
                mainHandler,
            )
            Log.i(TAG, "MediaSession: listening for active sessions")
            refreshActiveSession()
        } catch (se: SecurityException) {
            Log.w(TAG, "MediaSession: MEDIA_CONTENT_CONTROL missing — inactive (${se.message})")
            publish(inactivePayload(error = "security"))
        } catch (t: Throwable) {
            Log.w(TAG, "MediaSession: start failed — inactive (${t.message})")
            publish(inactivePayload(error = t.javaClass.simpleName))
        }
    }

    fun dispose() {
        mainHandler.removeCallbacks(progressTicker)
        try {
            sessionMgr?.removeOnActiveSessionsChangedListener(sessionsChangedListener)
        } catch (_: Throwable) {
        }
        detachController()
        sessionMgr = null
        started = false
    }

    private fun refreshActiveSession() {
        val mgr = sessionMgr ?: return
        val sessions: List<MediaController> = try {
            mgr.getActiveSessions(null as ComponentName?)
        } catch (se: SecurityException) {
            Log.w(TAG, "MediaSession: getActiveSessions SecurityException")
            publish(inactivePayload(error = "security"))
            return
        } catch (t: Throwable) {
            Log.w(TAG, "MediaSession: getActiveSessions failed: ${t.message}")
            publish(inactivePayload(error = t.javaClass.simpleName))
            return
        }

        val chosen = pickSession(sessions)
        if (chosen == null) {
            detachController()
            publish(inactivePayload())
            return
        }
        if (activeController?.sessionToken != chosen.sessionToken) {
            detachController()
            activeController = chosen
            chosen.registerCallback(controllerCallback, mainHandler)
            Log.i(
                TAG,
                "MediaSession: attached pkg=${chosen.packageName} " +
                    "state=${chosen.playbackState?.state}",
            )
        }
        emitFromController(chosen)
        armOrCancelTicker()
    }

    private fun pickSession(sessions: List<MediaController>): MediaController? {
        if (sessions.isEmpty()) return null
        val playing = sessions.firstOrNull { isPlaying(it.playbackState) && hasLabel(it) }
        if (playing != null) return playing
        val paused = sessions.firstOrNull {
            val st = it.playbackState?.state
            (st == PlaybackState.STATE_PAUSED || st == PlaybackState.STATE_PLAYING) &&
                hasLabel(it)
        }
        if (paused != null) return paused
        return sessions.firstOrNull { hasLabel(it) }
    }

    private fun hasLabel(c: MediaController): Boolean {
        val meta = c.metadata ?: return false
        val title = meta.getString(MediaMetadata.METADATA_KEY_TITLE)?.trim().orEmpty()
        val artist = meta.getString(MediaMetadata.METADATA_KEY_ARTIST)?.trim().orEmpty()
        val albumArtist =
            meta.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)?.trim().orEmpty()
        return title.isNotEmpty() || artist.isNotEmpty() || albumArtist.isNotEmpty()
    }

    private fun isPlaying(state: PlaybackState?): Boolean =
        state?.state == PlaybackState.STATE_PLAYING

    private fun emitFromController(controller: MediaController?) {
        if (controller == null) {
            publish(inactivePayload())
            return
        }
        val meta = controller.metadata
        val state = controller.playbackState
        val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE)?.trim().orEmpty()
        val artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)?.trim().orEmpty()
            .ifEmpty {
                meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)?.trim().orEmpty()
            }
        if (title.isEmpty() && artist.isEmpty()) {
            publish(inactivePayload())
            return
        }
        val duration = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val basePos = state?.position ?: 0L
        val adjusted = if (isPlaying(state) && state != null) {
            val last = state.lastPositionUpdateTime
            if (last > 0L) {
                basePos + (SystemClock.elapsedRealtime() - last)
            } else {
                basePos
            }
        } else {
            basePos
        }
        val progress = if (duration > 0L) {
            (adjusted.toDouble() / duration.toDouble()).coerceIn(0.0, 1.0)
        } else {
            0.0
        }
        val playing = isPlaying(state)
        publish(
            mapOf(
                "active" to true,
                "artist" to artist,
                "title" to title,
                "progress" to progress,
                "isPlaying" to playing,
                "packageName" to controller.packageName,
                "source" to "mediasession",
            ),
        )
    }

    private fun detachController() {
        mainHandler.removeCallbacks(progressTicker)
        try {
            activeController?.unregisterCallback(controllerCallback)
        } catch (_: Throwable) {
        }
        activeController = null
    }

    private fun armOrCancelTicker() {
        mainHandler.removeCallbacks(progressTicker)
        val c = activeController
        if (c != null && isPlaying(c.playbackState)) {
            mainHandler.postDelayed(progressTicker, TICK_MS)
        }
    }

    private fun publish(payload: Map<String, Any?>) {
        lastPayload = payload
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun inactivePayload(error: String? = null): Map<String, Any?> {
        val m = linkedMapOf<String, Any?>(
            "active" to false,
            "artist" to "",
            "title" to "",
            "progress" to 0.0,
            "isPlaying" to false,
            "source" to "mediasession",
        )
        if (error != null) m["error"] = error
        return m
    }

    companion object {
        private const val TICK_MS = 500L
    }
}

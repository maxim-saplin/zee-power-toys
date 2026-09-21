package com.zeepowertoys.zee_power_toys.boot

import android.app.Notification
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.zeepowertoys.zee_power_toys.MainActivity

/**
 * Lean foreground service — background keepalive for Zee Power Toys.
 *
 * Responsibilities:
 *   - Call startForeground() immediately on creation (mandatory for FGS).
 *   - Read `hudEnabled` from the intent extra (supplied by [BootReceiver])
 *     or, when started without a boot intent, fall back to [ConfigShim].
 *   - Log whether the HUD is enabled; HUD-engine ownership stays in the
 *     Activity host — the FGS must NOT spawn Flutter engines.
 *   - Return START_STICKY so the OS restarts the service if killed.
 *
 * Efficiency contract (ADR / PRINCIPLES hard gate):
 *   - NO wake locks.
 *   - NO AlarmManager / WorkManager.
 *   - Notification channel importance = IMPORTANCE_LOW (no sound/vibration).
 *   - The FGS itself is the only keepalive mechanism needed.
 *
 * Forward-compat note (API 34 / Android 14):
 *   - API 34 requires a foreground service type declared in the manifest and
 *     a matching type-specific permission (e.g. FOREGROUND_SERVICE_DATA_SYNC).
 *   - This service uses no GPS/camera/mic, so `dataSync` is the safest
 *     catch-all type.  The manifest declares `foregroundServiceType="dataSync"`
 *     and the permission `FOREGROUND_SERVICE_DATA_SYNC` for forward compat.
 *   - On API 32 (our emulator target) these are ignored but harmless.
 */
class ZeeForegroundService : Service() {

    companion object {
        private const val TAG = "ZEE"

        const val ACTION_BOOT = "com.zeepowertoys.zee_power_toys.action.BOOT"
        const val EXTRA_HUD_ENABLED = "hud_enabled"

        private const val NOTIF_CHANNEL_ID = "zee_fgs"
        private const val NOTIF_ID = 2001

        /** Best-effort runtime observability — read by ext.zee.bootState. */
        @Volatile var isRunning: Boolean = false
            private set

        /** Last-known hudEnabled value, updated each onStartCommand(). */
        @Volatile var lastHudEnabled: Boolean = true
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        isRunning = true
        Log.i(TAG, "ZeeForegroundService: onCreate — FGS started, notification posted")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // intent is null on START_STICKY restart; fall back to ConfigShim.
        val hudEnabled = if (intent != null) {
            intent.getBooleanExtra(EXTRA_HUD_ENABLED,
                ConfigShim.readHudEnabled(applicationContext))
        } else {
            // Restart after kill — re-read config synchronously.
            ConfigShim.readHudEnabled(applicationContext)
        }

        lastHudEnabled = hudEnabled

        if (hudEnabled) {
            Log.i(TAG, "ZeeForegroundService: onStartCommand — hudEnabled=true " +
                "(HUD engine is Activity responsibility, not FGS) — ensuring MainActivity")
            // START_STICKY restart / boot: Activity may be gone while FGS survives.
            // Re-launch so Presentation can (re)attach to secondary display.
            val launch = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
            runCatching { startActivity(launch) }
                .onFailure { Log.w(TAG, "ZeeForegroundService: MainActivity launch failed", it) }
        } else {
            Log.i(TAG, "ZeeForegroundService: onStartCommand — hudEnabled=false, " +
                "HUD engine will not be spawned")
        }

        // START_STICKY: OS restarts the service with a null intent if killed.
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        Log.i(TAG, "ZeeForegroundService: onDestroy")
        super.onDestroy()
    }

    // FGS does not support binding.
    override fun onBind(intent: Intent?): IBinder? = null

    // -------------------------------------------------------------------------
    // Notification
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "Zee Power Toys",
                    // IMPORTANCE_LOW: no sound, no vibration — minimal distraction.
                    NotificationManager.IMPORTANCE_LOW,
                )
                ch.description = "Keeps Zee Power Toys running in the background"
                mgr.createNotificationChannel(ch)
                Log.d(TAG, "ZeeForegroundService: notification channel created")
            }
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIF_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Zee Power Toys")
            .setContentText("Zee Power Toys running")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .build()
    }
}

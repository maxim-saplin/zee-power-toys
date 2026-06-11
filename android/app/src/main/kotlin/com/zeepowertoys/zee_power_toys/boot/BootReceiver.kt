package com.zeepowertoys.zee_power_toys.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver that fires on device boot and starts [ZeeForegroundService].
 *
 * Handles:
 *   android.intent.action.BOOT_COMPLETED  — standard AOSP boot complete
 *   android.intent.action.QUICKBOOT_POWERON — HTC/some OEM fast-boot variant
 *   com.zeepowertoys.TEST_BOOT             — debug/smoke-test alias (same code path;
 *       avoids the `BOOT_COMPLETED` protected-broadcast restriction on API 32+
 *       production-build emulators)
 *
 * Behaviour:
 *   1. Read `hudEnabled` via [ConfigShim] (plain SharedPreferences read, no Flutter).
 *   2. Start [ZeeForegroundService] unconditionally — the FGS is the background
 *      keepalive; it decides (via the same flag) whether to log HUD-disabled.
 *      Starting a FGS from a BroadcastReceiver requires the FOREGROUND_SERVICE
 *      permission and, on API 26+, Context.startForegroundService().
 *
 * No wake locks are acquired here — the FGS process keep-alive is sufficient.
 * directBootAware="false" in manifest: fires only after credential unlock.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != ACTION_TEST_BOOT) {
            return
        }

        Log.i(TAG, "BootReceiver: received $action — starting ZeeForegroundService")

        // Pre-Flutter config read (ADR 0003 boot shim privilege).
        val hudEnabled = ConfigShim.readHudEnabled(context)
        Log.i(TAG, "BootReceiver: hudEnabled=$hudEnabled")

        val serviceIntent = Intent(context, ZeeForegroundService::class.java).apply {
            putExtra(ZeeForegroundService.EXTRA_HUD_ENABLED, hudEnabled)
            setAction(ZeeForegroundService.ACTION_BOOT)
        }

        // API 26+: must use startForegroundService(); the service then has 5 s
        // to call startForeground() or the system will ANR-kill it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    companion object {
        private const val TAG = "ZEE"

        /**
         * Non-protected test alias for [Intent.ACTION_BOOT_COMPLETED].
         * Use via:
         *   adb shell am broadcast -a com.zeepowertoys.TEST_BOOT \
         *       -n com.zeepowertoys.zee_power_toys/.boot.BootReceiver
         * Registered in the main manifest so it works on production-build
         * emulators where BOOT_COMPLETED is a protected broadcast.
         */
        const val ACTION_TEST_BOOT = "com.zeepowertoys.TEST_BOOT"
    }
}

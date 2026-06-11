package com.zeepowertoys.zee_power_toys.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.zeepowertoys.zee_power_toys.usb.UsbModeController

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
 *   3. Block 0016: if `autoUsbPeripheral` flag is set in AppConfig, call
 *      [UsbModeController] to restore peripheral mode (persist.usb.mode="0").
 *      This mirrors zSupport's TimeZoneSyncReceiver boot logic (x0/f.o("0")).
 *      The write is a no-op off-car (not platform-signed); it is guarded inside
 *      [UsbModeController] and will never crash.
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

        // Block 0016: auto USB peripheral on boot.
        // zSupport's TimeZoneSyncReceiver does the same: on BOOT_COMPLETED,
        // if auto_usb_peripheral=true in SharedPrefs, call setprop persist.usb.mode 0.
        //
        // We read autoUsbPeripheral from the AppConfig JSON via ConfigShim.  On the
        // emulator the subsequent setUsbMode("0") will fail with requires-platform-signing;
        // that failure is caught inside UsbModeController and logged — never crashes.
        applyAutoUsbPeripheral(context)
    }

    // -------------------------------------------------------------------------
    // Auto USB peripheral — mirrors zSupport's BOOT_COMPLETED → setprop "0" flow.
    // -------------------------------------------------------------------------

    private fun applyAutoUsbPeripheral(context: Context) {
        val autoEnabled = ConfigShim.readAutoUsbPeripheral(context)
        Log.i(TAG, "BootReceiver: autoUsbPeripheral=$autoEnabled")
        if (!autoEnabled) return

        // Attempt to set peripheral mode.  Uses the same reflect → exec paths
        // as UsbModeController.setUsbMode(); failure is logged, not re-thrown.
        val result = runCatching {
            val clazz = Class.forName("android.os.SystemProperties")
            val set = clazz.getMethod("set", String::class.java, String::class.java)
            set.invoke(null, "persist.usb.mode", UsbModeController.VALUE_PERIPHERAL)
            Log.i(TAG, "BootReceiver: USB mode switched to peripheral on system boot (reflect)")
        }

        if (result.isFailure) {
            // Exec fallback (mirrors zSupport's TimeZoneSyncReceiver).
            runCatching {
                val proc = Runtime.getRuntime()
                    .exec(arrayOf("/system/bin/setprop", "persist.usb.mode",
                        UsbModeController.VALUE_PERIPHERAL))
                val exitCode = proc.waitFor()
                if (exitCode == 0) {
                    Log.i(TAG, "BootReceiver: USB mode switched to peripheral on system boot (exec)")
                } else {
                    // Expected on non-platform-signed builds (emulator / dev machine).
                    Log.d(TAG, "BootReceiver: autoUsbPeripheral setprop exitCode=$exitCode " +
                        "(requires platform signing — expected on emulator)")
                }
            }.onFailure { e ->
                Log.d(TAG, "BootReceiver: autoUsbPeripheral fallback exec failed", e)
            }
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

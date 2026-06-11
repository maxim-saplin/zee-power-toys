package com.zeepowertoys.zee_power_toys.usb

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native handler for the "zee/usb_mode" MethodChannel.
 *
 * Exposes three methods to the Dart layer:
 *
 *   getUsbMode   → String  raw property value: "0"=peripheral, "1"=host, ""=unknown
 *   setUsbMode   → Map {ok, reason?}  T3-only write; returns requires-platform-signing off-car
 *   isWritable   → Boolean  best-effort: can we set system properties?
 *
 * ── Mechanism (from zSupport-1.3.5 decompile, x0/f.smali) ───────────────────
 *
 * The property "persist.usb.mode" controls the USB role:
 *   "0" = Peripheral (ADB target — DHU visible to a PC over USB)
 *   "1" = Host (DHU is the USB host; ADB FROM the DHU to another device)
 *
 * zSupport shells out: Runtime.exec(["/system/bin/setprop", "persist.usb.mode", value]).
 * We prefer android.os.SystemProperties.set() via reflection (hidden API) because it
 * calls property_set() natively without spawning a child process — safer under
 * restrictive SELinux policies that block exec(system_file).
 * We fall back to Runtime.exec() if reflection fails (mirrors zSupport robustness).
 *
 * ── Signing requirement ───────────────────────────────────────────────────────
 *
 * Writing persist.* requires running as android.uid.system (platform key + sharedUserId).
 * On the emulator or any non-platform-signed build:
 *   - SystemProperties.set() throws SecurityException
 *   - Runtime.exec(setprop) exits with non-zero (permission denied)
 * Both paths are caught; the handler ALWAYS returns a result map — never re-throws.
 *
 * T3 (car, platform-signed): the write succeeds and the USB gadget role changes.
 * T2 (emulator):             setUsbMode returns {ok:false, reason:"requires-platform-signing"}.
 * T1 (Linux desktop):        the MethodChannel is never instantiated (no Android).
 */
class UsbModeController(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    companion object {
        private const val TAG = "ZEE.UsbMode"
        const val CHANNEL = "zee/usb_mode"

        // persist.usb.mode values (from zSupport x0/f.smali, e(String) method)
        const val VALUE_PERIPHERAL = "0"
        const val VALUE_HOST = "1"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result -> handleCall(call, result) }
        Log.i(TAG, "UsbModeController: channel registered")
    }

    fun tearDown() {
        channel.setMethodCallHandler(null)
    }

    // -------------------------------------------------------------------------
    // Dispatch
    // -------------------------------------------------------------------------

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUsbMode"  -> result.success(getUsbMode())
            "setUsbMode"  -> result.success(setUsbMode(call))
            "isWritable"  -> result.success(isWritable())
            else          -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // getUsbMode — read persist.usb.mode, unrestricted on any device.
    //
    // Uses SystemProperties.get() via reflection.  Falls back to Runtime.exec
    // if the reflection path fails (e.g. hidden API blocked on some future AOSP).
    // Returns the raw string: "0", "1", or "" (not set / unknown).
    // -------------------------------------------------------------------------

    private fun getUsbMode(): String {
        // Path 1: reflection on android.os.SystemProperties.get(key)
        val reflectResult = runCatching {
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod("get", String::class.java)
            val value = get.invoke(null, "persist.usb.mode") as String?
            Log.i(TAG, "getUsbMode (reflect): persist.usb.mode=\"$value\"")
            value ?: ""
        }
        if (reflectResult.isSuccess) return reflectResult.getOrDefault("")

        // Path 2: Runtime.exec getprop (matches zSupport x0/f.i() exactly)
        return runCatching {
            val proc = Runtime.getRuntime()
                .exec(arrayOf("/system/bin/getprop", "persist.usb.mode"))
            val value = proc.inputStream.bufferedReader().readLine() ?: ""
            proc.waitFor()
            Log.i(TAG, "getUsbMode (exec): persist.usb.mode=\"$value\"")
            value
        }.getOrElse { e ->
            Log.w(TAG, "getUsbMode: both paths failed", e)
            ""
        }
    }

    // -------------------------------------------------------------------------
    // setUsbMode — write persist.usb.mode (T3 only; guarded).
    //
    // value: "0" (peripheral) or "1" (host).
    //
    // Path 1: SystemProperties.set(key, value) via reflection — preferred because
    //   it calls property_set() natively; no child process, no exec SELinux denial.
    // Path 2: Runtime.exec(["/system/bin/setprop", "persist.usb.mode", value])
    //   fallback matching zSupport's x0/f.o(String) method.
    //
    // Both paths require android.uid.system (platform signing).
    // On the emulator (not system-UID):
    //   Path 1 throws SecurityException → {ok:false, reason:"requires-platform-signing"}
    //   Path 2 exits non-zero → same result.
    // -------------------------------------------------------------------------

    private fun setUsbMode(call: MethodCall): Map<String, Any?> {
        val value = call.argument<String>("value")
            ?: return mapOf("ok" to false, "reason" to "missing-value")

        if (value != VALUE_PERIPHERAL && value != VALUE_HOST) {
            return mapOf("ok" to false, "reason" to "invalid-value: expected 0 or 1, got \"$value\"")
        }

        Log.i(TAG, "setUsbMode: attempting persist.usb.mode=$value")

        // Path 1: hidden API SystemProperties.set()
        val reflectResult = runCatching {
            val clazz = Class.forName("android.os.SystemProperties")
            val set = clazz.getMethod("set", String::class.java, String::class.java)
            set.invoke(null, "persist.usb.mode", value)
            // Verify the write by reading back immediately.
            val readBack = getUsbMode()
            Log.i(TAG, "setUsbMode (reflect): wrote \"$value\"; readback=\"$readBack\"")
            mapOf("ok" to true, "path" to "reflect", "readBack" to readBack)
        }

        if (reflectResult.isSuccess) {
            return reflectResult.getOrDefault(mapOf("ok" to false, "reason" to "reflect-null"))
        }

        // Classify the reflection failure before trying exec.
        val reflectEx = reflectResult.exceptionOrNull()
        val reflectReason = when (reflectEx) {
            is SecurityException -> "requires-platform-signing"
            else -> "reflect-exception: ${reflectEx?.message}"
        }
        Log.w(TAG, "setUsbMode (reflect) failed: $reflectReason", reflectEx)

        // Path 2: exec /system/bin/setprop (mirrors zSupport x0/f.o())
        val execResult = runCatching {
            val proc = Runtime.getRuntime()
                .exec(arrayOf("/system/bin/setprop", "persist.usb.mode", value))
            val exitCode = proc.waitFor()
            if (exitCode == 0) {
                val readBack = getUsbMode()
                Log.i(TAG, "setUsbMode (exec): exitCode=0; readback=\"$readBack\"")
                mapOf("ok" to true, "path" to "exec", "readBack" to readBack)
            } else {
                val stderr = proc.errorStream.bufferedReader().readText().take(200)
                Log.w(TAG, "setUsbMode (exec): exitCode=$exitCode stderr=$stderr")
                mapOf("ok" to false, "reason" to "requires-platform-signing", "exitCode" to exitCode)
            }
        }

        if (execResult.isSuccess) {
            return execResult.getOrDefault(mapOf("ok" to false, "reason" to "exec-null"))
        }

        val execEx = execResult.exceptionOrNull()
        Log.w(TAG, "setUsbMode (exec) failed", execEx)
        // Both paths failed — report the original reflection reason (more informative
        // for a non-system-signed build).
        return mapOf("ok" to false, "reason" to reflectReason)
    }

    // -------------------------------------------------------------------------
    // isWritable — best-effort: can this process set system properties?
    //
    // We probe by attempting to load the SystemProperties class and checking if
    // the "set" method is accessible.  This is not a write attempt — it does not
    // change any property.  Returns false on any exception.
    //
    // Note: even if this returns true, the actual write may still fail at runtime
    // (e.g. SELinux context mismatch).  Use the {ok, reason} from setUsbMode for
    // the authoritative answer.
    // -------------------------------------------------------------------------

    private fun isWritable(): Boolean {
        return runCatching {
            val clazz = Class.forName("android.os.SystemProperties")
            // Probe: can we resolve the "set" method? On non-system builds the
            // class exists but the method is guarded by SecurityManager at invocation
            // time, so we cannot distinguish "yes" from "no" without a dry run.
            // We return true here (optimistic) to avoid false negatives; the UI
            // disables controls based on the first setUsbMode failure, not this probe.
            clazz.getMethod("set", String::class.java, String::class.java)
            // If we're running as system UID (T3 car), return true.
            // On emulator isWritable() returns true optimistically; the UI
            // switches to disabled only after the first setUsbMode returns
            // {ok:false, reason:"requires-platform-signing"}.
            true
        }.getOrElse { false }
    }
}

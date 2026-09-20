package com.zeepowertoys.zee_power_toys.boot

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Pre-Flutter native read of the app's SharedPreferences config.
 *
 * ADR 0003: the boot shim is the single privileged pre-Flutter read.
 * It reads the `flutter.zee.config` JSON string from the
 * `FlutterSharedPreferences` SharedPreferences file (the file Flutter's
 * shared_preferences plugin uses on Android) and extracts the flags
 * the boot policy needs — specifically `hudEnabled`.
 *
 * 0054: when SharedPreferences are empty (fresh install after `adb uninstall`
 * forced by SHARED_USER_INCOMPATIBLE / signing flip), fall back to the durable
 * mirror at `/sdcard/zee-power-toys/config.json` written by SharedPrefsConfigStore.
 *
 * SharedPreferences details (confirmed against shared_preferences_android 2.4.26):
 *   - SP file name : "FlutterSharedPreferences"
 *     → on-disk: <data>/data/<pkg>/shared_prefs/FlutterSharedPreferences.xml
 *   - Key for AppConfig: "flutter.zee.config"
 *     (Flutter's shared_preferences adds the "flutter." namespace prefix)
 *   - Value: JSON string, e.g. {"hudBoxOn":false,"hudEnabled":true,...}
 *
 * No wake locks.  No background threads.  Synchronous read only.
 */
internal object ConfigShim {

    private const val TAG = "ZEE"
    private const val SP_FILE = "FlutterSharedPreferences"
    private const val CONFIG_KEY = "flutter.zee.config"

    /** Durable mirror written by Dart [SharedPrefsConfigStore] (survives uninstall). */
    private val DURABLE_MIRROR_CANDIDATES = arrayOf(
        "/sdcard/zee-power-toys/config.json",
        "/storage/emulated/0/zee-power-toys/config.json",
    )

    /**
     * Returns `hudEnabled` from the persisted AppConfig.
     * Defaults to **true** (HUD on) when the key is absent or the JSON
     * cannot be parsed — fail-open is safer than silently disabling the HUD.
     */
    fun readHudEnabled(context: Context): Boolean {
        return readBooleanField(context, "hudEnabled", default = true)
    }

    /**
     * Returns `autoUsbPeripheral` from the persisted AppConfig.
     * Defaults to **false** when absent — do not force USB mode unless explicitly set.
     * Block 0016: read by BootReceiver to re-apply peripheral on BOOT_COMPLETED.
     */
    fun readAutoUsbPeripheral(context: Context): Boolean {
        return readBooleanField(context, "autoUsbPeripheral", default = false)
    }

    // -------------------------------------------------------------------------
    // Shared JSON field reader.
    // -------------------------------------------------------------------------

    private fun readBooleanField(context: Context, field: String, default: Boolean): Boolean {
        return try {
            val raw = readConfigJson(context)
            if (raw == null) {
                Log.d(TAG, "ConfigShim: no prefs/mirror — defaulting $field=$default")
                return default
            }
            val json = JSONObject(raw)
            val result = json.optBoolean(field, default)
            Log.i(TAG, "ConfigShim: read $field=$result")
            result
        } catch (e: Exception) {
            Log.w(TAG, "ConfigShim: failed to read config, defaulting $field=$default", e)
            default
        }
    }

    /** Prefs first; durable `/sdcard/zee-power-toys/config.json` if prefs empty (0054). */
    private fun readConfigJson(context: Context): String? {
        val prefs = context.applicationContext
            .getSharedPreferences(SP_FILE, Context.MODE_PRIVATE)
        val fromPrefs = prefs.getString(CONFIG_KEY, null)
        if (!fromPrefs.isNullOrBlank()) return fromPrefs

        for (path in DURABLE_MIRROR_CANDIDATES) {
            try {
                val file = File(path)
                if (file.isFile) {
                    val text = file.readText()
                    if (text.isNotBlank()) {
                        Log.i(TAG, "ConfigShim: restored config from durable mirror $path")
                        // Seed prefs so subsequent Flutter load sees the same JSON.
                        prefs.edit().putString(CONFIG_KEY, text).apply()
                        return text
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "ConfigShim: durable mirror read failed for $path", e)
            }
        }
        return null
    }
}

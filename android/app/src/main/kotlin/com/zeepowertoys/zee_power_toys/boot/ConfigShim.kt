package com.zeepowertoys.zee_power_toys.boot

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * Pre-Flutter native read of the app's SharedPreferences config.
 *
 * ADR 0003: the boot shim is the single privileged pre-Flutter read.
 * It reads the `flutter.zee.config` JSON string from the
 * `FlutterSharedPreferences` SharedPreferences file (the file Flutter's
 * shared_preferences plugin uses on Android) and extracts the flags
 * the boot policy needs — specifically `hudEnabled`.
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

    /**
     * Returns `hudEnabled` from the persisted AppConfig.
     * Defaults to **true** (HUD on) when the key is absent or the JSON
     * cannot be parsed — fail-open is safer than silently disabling the HUD.
     */
    fun readHudEnabled(context: Context): Boolean {
        return try {
            val prefs = context.applicationContext
                .getSharedPreferences(SP_FILE, Context.MODE_PRIVATE)
            val raw = prefs.getString(CONFIG_KEY, null)
            if (raw == null) {
                Log.d(TAG, "ConfigShim: key '$CONFIG_KEY' absent — defaulting hudEnabled=true")
                return true
            }
            val json = JSONObject(raw)
            // optBoolean: returns the default when the key is missing or not a boolean.
            val result = json.optBoolean("hudEnabled", true)
            Log.i(TAG, "ConfigShim: read hudEnabled=$result from '$CONFIG_KEY'")
            result
        } catch (e: Exception) {
            Log.w(TAG, "ConfigShim: failed to read config, defaulting hudEnabled=true", e)
            true
        }
    }
}

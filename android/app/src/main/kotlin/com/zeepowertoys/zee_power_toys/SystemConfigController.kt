package com.zeepowertoys.zee_power_toys

import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Native handler for the "zee/system_config" MethodChannel.
 *
 * Exposes four methods to the Dart layer:
 *
 *   systemLocale      → String (BCP-47 tag, e.g. "en-US", "ru-RU")
 *   setSystemLanguage → Map {ok, reason?}  (T3-only write; guarded)
 *   setClusterLanguage→ Map {ok, reason?}  (T3-only write via AdaptAPI; guarded)
 *   clusterSupported  → Boolean            (false on emulator, true on car)
 *
 * ── phase0-derived mechanism ─────────────────────────────────────────────────
 *
 * SYSTEM LANGUAGE (setSystemLanguage):
 *   Uses ActivityManager.updateConfiguration() with a new Configuration + Locale.
 *   This requires android.permission.CHANGE_CONFIGURATION — a signature-level
 *   permission granted only to Zeekr system APKs (T3).  On the emulator the call
 *   is attempted first; SecurityException is caught and reported as
 *   {ok:false, reason:"unsupported-on-device"}.
 *
 * CLUSTER LANGUAGE (setClusterLanguage) — two paths from ClusterLocaleProbe:
 *
 *   Path 1 (binary flag, ICarFunction):
 *     com.ecarx.xui.adaptapi.car.Car.create(context)
 *       .getICarFunction()
 *       .setFunctionValue(LOCALE_FUNC_ID=0x20318a00, intValue)
 *     intValue: 0 = Chinese, 1 = non-Chinese
 *     LOCALE_FUNC_ID = SETTING_FUNC_LOCAL_CHANGED from the ecarx AdaptAPI
 *
 *   Path 3 (37-language enum, IOtaSession):
 *     car.getIOtaSession().setSystemHMILanguage(langEnum.toLong())
 *     Enum used by the OTA update layer (langEnum 11=English_US, 30=Russian).
 *     Fallback: AdaptInternalManager.set("Adapt-OTA","SET_SYSTEM_HMI_LANGUAGE",JSON)
 *
 *   Both paths require the ecarx AdaptAPI (com.ecarx.xui.adaptapi.car.Car class).
 *   ClassNotFoundException → {ok:false, reason:"unsupported-on-device"}.
 *
 * ── Guard strategy ────────────────────────────────────────────────────────────
 *   All reflective / privileged calls are wrapped in runCatching; the handler
 *   ALWAYS returns a result map — never re-throws to Flutter, never crashes.
 *   This satisfies the "no crash off-car" constraint.
 */
class SystemConfigController(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger
) {
    companion object {
        private const val TAG = "ZEE.SysCfg"
        private const val CHANNEL = "zee/system_config"

        // AdaptAPI SETTING_FUNC_LOCAL_CHANGED (Path 1, ClusterLocaleProbe)
        private const val LOCALE_FUNC_ID = 0x20318a00

        // 37-language enum used by Path 3 IOtaSession.setSystemHMILanguage
        // (map from phase0 ClusterLocaleProbe LANG_NAMES)
        private val LANG_ENUM = mapOf(
            "ar" to 1, "bg" to 2,
            "zh-HK" to 3, "zh-TW" to 3,  // Traditional Cantonese
            "zh" to 4, "zh-CN" to 4,       // Simplified
            "cs" to 6, "da" to 7, "nl" to 8,
            "en-AU" to 9, "en-GB" to 10, "en" to 11, "en-US" to 11,
            "et" to 12, "fi" to 13,
            "fr-CA" to 15, "fr" to 16,
            "de" to 17, "el" to 18, "hu" to 19, "it" to 20,
            "ja" to 21, "ko" to 22, "lv" to 23, "lt" to 24,
            "nb" to 25, "no" to 25, "pl" to 26,
            "pt-BR" to 27, "pt" to 28, "ro" to 29,
            "ru" to 30, "sk" to 31, "sl" to 32,
            "es" to 33, "es-US" to 34, "sv" to 35,
            "th" to 36, "tr" to 37
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            handleCall(call, result)
        }
        Log.i(TAG, "SystemConfigController: channel registered")
    }

    fun tearDown() {
        channel.setMethodCallHandler(null)
    }

    // -------------------------------------------------------------------------
    // Dispatch
    // -------------------------------------------------------------------------

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "systemLocale"       -> result.success(getSystemLocale())
            "setSystemLanguage"  -> result.success(setSystemLanguage(call))
            "setClusterLanguage" -> result.success(setClusterLanguage(call))
            "clusterSupported"   -> result.success(isClusterSupported())
            else                 -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // systemLocale — read current Android locale
    // -------------------------------------------------------------------------

    private fun getSystemLocale(): String {
        // API 24+ has the well-formed Locale.toLanguageTag(); below that use
        // the classic language/country fields.
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            locale.toLanguageTag() // "en-US", "ru-RU", etc.
        } else {
            val tag = locale.language +
                    (if (locale.country.isNotEmpty()) "-${locale.country}" else "")
            tag
        }
    }

    // -------------------------------------------------------------------------
    // setSystemLanguage — attempt to change Android system language
    //
    // Requires android.permission.CHANGE_CONFIGURATION (signature-level).
    // On emulator/stock Android → SecurityException → {ok:false, unsupported}.
    // On Zeekr car (T3) the permission is granted → updates configuration.
    // -------------------------------------------------------------------------

    private fun setSystemLanguage(call: MethodCall): Map<String, Any?> {
        val tag = call.argument<String>("languageTag")
            ?: return mapOf("ok" to false, "reason" to "missing-languageTag")

        Log.i(TAG, "setSystemLanguage: tag=$tag")

        return runCatching {
            val locale = parseLocaleTag(tag)
            val conf = context.resources.configuration
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                conf.setLocale(locale)
            } else {
                @Suppress("DEPRECATION")
                conf.locale = locale
            }
            @Suppress("DEPRECATION")
            context.resources.updateConfiguration(conf, context.resources.displayMetrics)
            Log.i(TAG, "setSystemLanguage: success locale=$locale")
            mapOf("ok" to true)
        }.getOrElse { e ->
            val reason = when (e) {
                is SecurityException -> "unsupported-on-device"
                else -> "exception: ${e.message}"
            }
            Log.w(TAG, "setSystemLanguage failed: $reason", e)
            mapOf("ok" to false, "reason" to reason)
        }
    }

    // -------------------------------------------------------------------------
    // setClusterLanguage — attempt via AdaptAPI (T3 only)
    //
    // Path 1: ICarFunction.setFunctionValue(0x20318a00, value)
    //         Binary flag: 0 = Chinese, 1 = non-Chinese.
    // Path 3: IOtaSession.setSystemHMILanguage(langEnum)
    //         37-language enum. Fallback: AdaptInternalManager.set().
    //
    // All paths guarded: ClassNotFoundException or SecurityException →
    // {ok:false, reason:"unsupported-on-device"}
    // -------------------------------------------------------------------------

    private fun setClusterLanguage(call: MethodCall): Map<String, Any?> {
        val tag = call.argument<String>("languageTag")
            ?: return mapOf("ok" to false, "reason" to "missing-languageTag")

        Log.i(TAG, "setClusterLanguage: tag=$tag")

        // First check: can we even find the AdaptAPI class?
        val carClass = runCatching {
            Class.forName("com.ecarx.xui.adaptapi.car.Car")
        }.getOrNull()

        if (carClass == null) {
            Log.w(TAG, "setClusterLanguage: AdaptAPI Car class not found — unsupported-on-device")
            return mapOf("ok" to false, "reason" to "unsupported-on-device")
        }

        // Try Path 3 first (rich 37-language enum) — more expressive.
        val langEnum = resolveClusterLangEnum(tag)
        Log.i(TAG, "setClusterLanguage: langEnum=$langEnum for tag=$tag")

        return runCatching {
            val iCar = carClass.getMethod("create", Context::class.java)
                .invoke(null, context)
                ?: return mapOf("ok" to false, "reason" to "car-create-null")

            // Path 3: IOtaSession
            val otaSession = runCatching {
                iCar.javaClass.getMethod("getIOtaSession").invoke(iCar)
                    ?: iCar.javaClass.getMethod("getOtaSession").invoke(iCar)
            }.getOrNull()

            if (otaSession != null) {
                val setLang = otaSession.javaClass.getMethod(
                    "setSystemHMILanguage", Long::class.javaPrimitiveType)
                setLang.invoke(otaSession, langEnum.toLong())
                Log.i(TAG, "setClusterLanguage Path3: setSystemHMILanguage($langEnum) ok")
                return mapOf("ok" to true, "path" to "Path3_IOtaSession", "langEnum" to langEnum)
            }

            // Path 1 fallback: binary ICarFunction value
            val carFunction = iCar.javaClass.getMethod("getICarFunction").invoke(iCar)
                ?: return mapOf("ok" to false, "reason" to "ICarFunction-unavailable")

            val binaryValue = if (tag.startsWith("zh")) 0 else 1
            val setFunc = carFunction.javaClass.getMethod(
                "setFunctionValue", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
            setFunc.invoke(carFunction, LOCALE_FUNC_ID, binaryValue)
            Log.i(TAG, "setClusterLanguage Path1: setFunctionValue(0x${"%08X".format(LOCALE_FUNC_ID)}, $binaryValue) ok")
            mapOf("ok" to true, "path" to "Path1_ICarFunction", "binaryValue" to binaryValue)

        }.getOrElse { e ->
            val reason = when (e) {
                is SecurityException -> "unsupported-on-device"
                is ClassNotFoundException, is NoSuchMethodException -> "unsupported-on-device"
                else -> "exception: ${e.message}"
            }
            Log.w(TAG, "setClusterLanguage failed: $reason", e)
            mapOf("ok" to false, "reason" to reason)
        }
    }

    // -------------------------------------------------------------------------
    // clusterSupported — probe AdaptAPI class presence
    // -------------------------------------------------------------------------

    private fun isClusterSupported(): Boolean {
        val available = runCatching {
            Class.forName("com.ecarx.xui.adaptapi.car.Car")
            true
        }.getOrDefault(false)
        Log.i(TAG, "clusterSupported: $available")
        return available
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /** Resolve the 37-language OTA enum for a given BCP-47 tag. */
    private fun resolveClusterLangEnum(tag: String): Int {
        // Exact match first, then language-only fallback.
        return LANG_ENUM[tag]
            ?: LANG_ENUM[tag.split("-").first()]
            ?: 11 // fallback: English_US
    }

    /** Parse a BCP-47-ish tag to java.util.Locale.
     *  Handles "en", "en-US", "ru-RU", "zh-CN". */
    private fun parseLocaleTag(tag: String): Locale {
        val parts = tag.replace("_", "-").split("-")
        return when (parts.size) {
            1    -> Locale(parts[0])
            2    -> Locale(parts[0], parts[1])
            else -> Locale(parts[0], parts[1], parts[2])
        }
    }
}

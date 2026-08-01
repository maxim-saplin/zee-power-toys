package com.zeepowertoys.zee_power_toys

import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native handler for the "zee/system_config" MethodChannel.
 *
 * Exposes five methods to the Dart layer:
 *
 *   systemLocale      → String (BCP-47 tag, e.g. "en-US", "ru-RU")
 *   setSystemLanguage → Map {ok, reason?}  (T3-only write via AdaptAPI/OTA; guarded)
 *   setClusterLanguage→ Map {ok, reason?}  (T3-only write via AdaptAPI; guarded)
 *   clusterSupported  → Boolean            (false on emulator, true on car)
 *   systemSupported   → Boolean            (false on emulator, true on car)
 *
 * ── phase0-derived mechanism ─────────────────────────────────────────────────
 *
 * SYSTEM LANGUAGE (setSystemLanguage):
 *   There is no persistent, system-wide way to change the Android locale from
 *   an unprivileged app: the platform API for that needs a signature-level,
 *   privileged permission that is deliberately NOT declared in this app's
 *   manifest (declaring it would be pointless — it cannot be granted without
 *   platform signing, which is out of scope this wave) and the unprivileged
 *   fallback (mutating this process's own resource-configuration snapshot)
 *   is not persistent and not system-wide anyway — a prior version of this
 *   method did exactly that and reported success, which was an illusion.
 *   Instead this method reuses the AdaptAPI/OTA mechanism already proven for
 *   cluster language below:
 *     car.getIOtaSession().setSystemHMILanguage(langEnum.toLong())
 *   — note the call's own name says *System*, not just cluster — with the
 *   AdaptInternalManager.set("Adapt-OTA","SET_SYSTEM_HMI_LANGUAGE",JSON)
 *   fallback if IOtaSession is unavailable. Both require the ecarx AdaptAPI
 *   (com.ecarx.xui.adaptapi.car.Car); absent on T1/T2 → {ok:false,
 *   reason:"unsupported-on-device"}. Present but denied at the reflective call
 *   → {ok:false, reason:"no-privilege"}. Whether the OTA call actually
 *   changes the car's system language can only be confirmed on T3 (see
 *   docs/issues/BACKLOG.md) — untested here, and may still fail on-car this
 *   wave without platform signing.
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
            "systemSupported"    -> result.success(isSystemSupported())
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
    // setSystemLanguage — attempt to change the car's system HMI language via
    // the AdaptAPI/OTA path (Task 3 fix — see the class doc comment above).
    //
    // No privileged-permission gate here: the platform permission this used
    // to check for can never be granted to this app (not declared in the
    // manifest, signature-level, requires platform signing this app does not
    // have) so checking for it only ever produced a denial that looked like a
    // capability check but was really just describing our own manifest. The
    // real capability question is "is the ecarx AdaptAPI present" — reported
    // via [systemSupported] and the reason codes below.
    // -------------------------------------------------------------------------

    private fun setSystemLanguage(call: MethodCall): Map<String, Any?> {
        val tag = call.argument<String>("languageTag")
            ?: return mapOf("ok" to false, "reason" to "missing-languageTag")

        Log.i(TAG, "setSystemLanguage: tag=$tag — probing AdaptAPI (OTA path)")

        val iCar = acquireCar()
        if (iCar == null) {
            Log.w(TAG, "setSystemLanguage: AdaptAPI Car unavailable — unsupported-on-device")
            return mapOf("ok" to false, "reason" to "unsupported-on-device")
        }

        val langEnum = resolveClusterLangEnum(tag)
        Log.i(TAG, "setSystemLanguage: langEnum=$langEnum for tag=$tag")

        return runCatching {
            // Primary: IOtaSession.setSystemHMILanguage — its own name says
            // *System*, which is why it is the primary path here (not just
            // for cluster language below).
            val otaSession = runCatching {
                iCar.javaClass.getMethod("getIOtaSession").invoke(iCar)
                    ?: iCar.javaClass.getMethod("getOtaSession").invoke(iCar)
            }.getOrNull()

            if (otaSession != null) {
                val setLang = otaSession.javaClass.getMethod(
                    "setSystemHMILanguage", Long::class.javaPrimitiveType)
                setLang.invoke(otaSession, langEnum.toLong())
                Log.i(TAG, "setSystemLanguage: IOtaSession.setSystemHMILanguage($langEnum) ok")
                return@runCatching mapOf("ok" to true, "path" to "IOtaSession", "langEnum" to langEnum)
            }

            // Fallback documented alongside the primary path (class doc :41):
            // AdaptInternalManager.set("Adapt-OTA","SET_SYSTEM_HMI_LANGUAGE",JSON).
            // The exact package for AdaptInternalManager is not confirmed by any
            // grounding doc in this repo (unlike Car, whose path is verified) —
            // best-effort guess alongside com.ecarx.xui.adaptapi.car.Car; any
            // ClassNotFoundException here is classified below same as an absent
            // AdaptAPI, so this fallback can never make a false claim of success.
            val mgrClass = Class.forName("com.ecarx.xui.adaptapi.AdaptInternalManager")
            val setMethod = mgrClass.getMethod(
                "set", String::class.java, String::class.java, String::class.java)
            val json = "{\"language\":$langEnum}"
            setMethod.invoke(null, "Adapt-OTA", "SET_SYSTEM_HMI_LANGUAGE", json)
            Log.i(TAG, "setSystemLanguage: AdaptInternalManager fallback ok")
            mapOf("ok" to true, "path" to "AdaptInternalManager", "langEnum" to langEnum)
        }.getOrElse { e ->
            val reason = when (e) {
                is SecurityException -> "no-privilege"
                is ClassNotFoundException, is NoSuchMethodException -> "unsupported-on-device"
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

        val iCar = acquireCar()
        if (iCar == null) {
            Log.w(TAG, "setClusterLanguage: AdaptAPI Car unavailable — unsupported-on-device")
            return mapOf("ok" to false, "reason" to "unsupported-on-device")
        }

        // Try Path 3 first (rich 37-language enum) — more expressive.
        val langEnum = resolveClusterLangEnum(tag)
        Log.i(TAG, "setClusterLanguage: langEnum=$langEnum for tag=$tag")

        return runCatching {
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
    // clusterSupported / systemSupported — probe AdaptAPI class presence.
    //
    // Both language writes share the same capability question ("is the ecarx
    // AdaptAPI present on this device") so both probes delegate to
    // [isAdaptApiPresent]. Kept as two named methods (not one) because they
    // answer two distinct Dart-side questions the picker UI gates on
    // separately — a future firmware could plausibly expose one without the
    // other even though today both are the same class-presence check.
    // -------------------------------------------------------------------------

    private fun isClusterSupported(): Boolean {
        val available = isAdaptApiPresent()
        Log.i(TAG, "clusterSupported: $available")
        return available
    }

    private fun isSystemSupported(): Boolean {
        val available = isAdaptApiPresent()
        Log.i(TAG, "systemSupported: $available")
        return available
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun isAdaptApiPresent(): Boolean = runCatching {
        Class.forName("com.ecarx.xui.adaptapi.car.Car")
        true
    }.getOrDefault(false)

    /**
     * Acquire the ecarx AdaptAPI `Car` instance via reflection, or null if the
     * AdaptAPI class/instance is unavailable on this device (T1/T2 — no
     * ecarx framework, e.g. stock Android or this emulator).
     *
     * Extracted from the Car.create() acquisition already proven for cluster
     * language so [setSystemLanguage] and [setClusterLanguage] share the exact
     * same acquisition path (Task 3) instead of two copies drifting apart.
     */
    private fun acquireCar(): Any? {
        val carClass = runCatching {
            Class.forName("com.ecarx.xui.adaptapi.car.Car")
        }.getOrNull() ?: return null
        return runCatching {
            carClass.getMethod("create", Context::class.java).invoke(null, context)
        }.getOrNull()
    }

    /** Resolve the 37-language OTA enum for a given BCP-47 tag. */
    private fun resolveClusterLangEnum(tag: String): Int {
        // Exact match first, then language-only fallback.
        return LANG_ENUM[tag]
            ?: LANG_ENUM[tag.split("-").first()]
            ?: 11 // fallback: English_US
    }

}

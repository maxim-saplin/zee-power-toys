package com.zeepowertoys.zee_power_toys.boot

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import com.zeepowertoys.zee_power_toys.carsignals.ReflectionUtils

/**
 * Phase0-style boot remediations (zee_hud_2 BootActions), trimmed to what we
 * still need on the DHU:
 *   - push cluster locale → English (AdaptAPI 0x20318a00 = 1)
 *   - optional Doze whitelist for YNavi
 *   - silent force-stop YNavi (manual / recovery; no automatic network loop)
 *
 * Automatic YNavi-network recovery is intentionally NOT ported — phase0
 * retired it; traffic fix lives in the YNavi mod.
 */
object BootRemediation {
    private const val TAG = "ZEE"
    private const val YNAVI_PACKAGE = "ru.yandex.yandexnavi"
    private const val LOCALE_FUNC_ID = 0x20318a00
    private const val LOCALE_ENGLISH = 1
    private const val LOCALE_RETRY_COUNT = 3
    private const val LOCALE_RETRY_DELAY_MS = 1000L

    /** Fire-and-forget boot path: locale + doze. Never throws into BootReceiver. */
    fun runOnBootAsync(context: Context) {
        val app = context.applicationContext
        val thread = HandlerThread("ZeeBootRemediation").also { it.start() }
        Handler(thread.looper).post {
            try {
                val localeOk = pushClusterLocaleEnglish(app)
                val dozeOk = addDozeWhitelist(app)
                Log.i(TAG, "BootRemediation: localeOk=$localeOk dozeOk=$dozeOk")
            } catch (e: Exception) {
                Log.w(TAG, "BootRemediation: unexpected failure", e)
            } finally {
                thread.quitSafely()
            }
        }
    }

    fun pushClusterLocaleEnglish(context: Context): Boolean {
        for (attempt in 1..LOCALE_RETRY_COUNT) {
            try {
                val carClass = ReflectionUtils.classForName("com.ecarx.xui.adaptapi.car.Car")
                    ?: run {
                        Log.w(TAG, "BootRemediation: AdaptAPI Car class missing")
                        return false
                    }
                val iCar = ReflectionUtils.callStatic(carClass, "create", context)
                    ?: run {
                        Log.w(TAG, "BootRemediation: Car.create null")
                        return false
                    }
                val carFunction = ReflectionUtils.callInstance(iCar, "getICarFunction")
                    ?: run {
                        Log.w(TAG, "BootRemediation: ICarFunction unavailable")
                        return false
                    }
                val write = ReflectionUtils.callInstanceResult(
                    carFunction,
                    "setFunctionValue",
                    LOCALE_FUNC_ID,
                    LOCALE_ENGLISH,
                )
                if (write.error != null) {
                    Log.w(TAG, "BootRemediation: locale write attempt $attempt: ${write.error.message}")
                    if (attempt < LOCALE_RETRY_COUNT) {
                        Thread.sleep(LOCALE_RETRY_DELAY_MS)
                        continue
                    }
                    return false
                }
                Log.i(TAG, "BootRemediation: cluster locale → English (attempt $attempt)")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "BootRemediation: locale attempt $attempt: ${e.message}")
                if (attempt < LOCALE_RETRY_COUNT) {
                    try {
                        Thread.sleep(LOCALE_RETRY_DELAY_MS)
                    } catch (_: InterruptedException) {
                    }
                }
            }
        }
        return false
    }

    fun restartYNaviSilent(context: Context): Boolean {
        return try {
            val am = context.getSystemService(ActivityManager::class.java) ?: return false
            val method = am.javaClass.getMethod("forceStopPackage", String::class.java)
            method.invoke(am, YNAVI_PACKAGE)
            Log.i(TAG, "BootRemediation: force-stopped $YNAVI_PACKAGE")
            true
        } catch (e: Exception) {
            Log.e(TAG, "BootRemediation: restartYNavi failed", e)
            false
        }
    }

    fun addDozeWhitelist(context: Context): Boolean {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                ?: return false
            if (pm.isIgnoringBatteryOptimizations(YNAVI_PACKAGE)) {
                Log.d(TAG, "BootRemediation: YNavi already Doze-whitelisted")
                return true
            }
            val dmClass = Class.forName("android.os.IDeviceIdleController\$Stub")
            val asInterface = dmClass.getMethod("asInterface", android.os.IBinder::class.java)
            val smClass = Class.forName("android.os.ServiceManager")
            val getService = smClass.getMethod("getService", String::class.java)
            val binder = getService.invoke(null, "deviceidle") as? android.os.IBinder ?: return false
            val controller = asInterface.invoke(null, binder)
            val addMethod = controller.javaClass.getMethod(
                "addPowerSaveWhitelistApp",
                String::class.java,
            )
            addMethod.invoke(controller, YNAVI_PACKAGE)
            Log.i(TAG, "BootRemediation: added YNavi to Doze whitelist")
            true
        } catch (e: Exception) {
            Log.w(TAG, "BootRemediation: Doze whitelist failed: ${e.message}")
            false
        }
    }
}

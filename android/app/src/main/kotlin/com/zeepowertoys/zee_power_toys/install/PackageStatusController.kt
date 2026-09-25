package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel "zee/packages":
 * - isInstalled(packageName) → "installed" | "missing" | "unknown" (legacy)
 * - probe(packageName) → { state, versionCode?, versionName? } (0103)
 */
class PackageStatusController(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, METHOD_CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalled" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.success("unknown")
                        return@setMethodCallHandler
                    }
                    result.success(probeState(pkg))
                }
                "probe" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.success(
                            mapOf(
                                "state" to "unknown",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    result.success(probeMap(pkg))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun probeState(packageName: String): String {
        return try {
            info(packageName)
            "installed"
        } catch (_: PackageManager.NameNotFoundException) {
            "missing"
        } catch (_: Throwable) {
            "unknown"
        }
    }

    private fun probeMap(packageName: String): Map<String, Any?> {
        return try {
            val pi = info(packageName)
            val code =
                if (Build.VERSION.SDK_INT >= 28) {
                    pi.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    pi.versionCode.toLong()
                }
            mapOf(
                "state" to "installed",
                "versionCode" to code,
                "versionName" to pi.versionName,
            )
        } catch (_: PackageManager.NameNotFoundException) {
            mapOf("state" to "missing")
        } catch (_: Throwable) {
            mapOf("state" to "unknown")
        }
    }

    private fun info(packageName: String) =
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(packageName, 0)
        }

    companion object {
        private const val METHOD_CHANNEL = "zee/packages"
    }
}

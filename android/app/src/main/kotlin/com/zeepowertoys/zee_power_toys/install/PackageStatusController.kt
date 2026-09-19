package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel "zee/packages" — isInstalled(packageName) →
 * "installed" | "missing" | "unknown".
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
                    result.success(probe(pkg))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun probe(packageName: String): String {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                context.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(packageName, 0)
            }
            "installed"
        } catch (_: PackageManager.NameNotFoundException) {
            "missing"
        } catch (_: Throwable) {
            "unknown"
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "zee/packages"
    }
}

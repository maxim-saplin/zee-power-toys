package com.zeepowertoys.zee_power_toys.install

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel "zee/packages":
 * - isInstalled(packageName) → "installed" | "missing" | "unknown" (legacy)
 * - probe(packageName) → { state, versionCode?, versionName? } (0103)
 * - requestUninstall(packageName) → { status: launched|failed|unsupported, message? } (0121)
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
                "requestUninstall" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.success(
                            mapOf(
                                "status" to "failed",
                                "message" to "packageName required",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    result.success(launchUninstall(pkg))
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


    /**
     * 0121: open the system uninstall sheet (ACTION_DELETE). User must confirm.
     * Never silent — surfaces failed/unsupported honestly when the activity
     * cannot start (policy / no resolver).
     */
    private fun launchUninstall(packageName: String): Map<String, Any?> {
        return try {
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            val resolved = intent.resolveActivity(context.packageManager)
            if (resolved == null) {
                Log.w(TAG, "requestUninstall: no resolver for $packageName")
                return mapOf(
                    "status" to "failed",
                    "message" to "No system uninstall activity for $packageName",
                )
            }
            Log.i(TAG, "requestUninstall: starting DELETE for $packageName → $resolved")
            // MainActivity context: start without NEW_TASK so pause/resume bookends confirm.
            context.startActivity(intent)
            mapOf("status" to "launched")
        } catch (t: Throwable) {
            Log.e(TAG, "requestUninstall failed for $packageName", t)
            mapOf(
                "status" to "failed",
                "message" to (t.message ?: t.javaClass.simpleName),
            )
        }
    }

    companion object {
        private const val TAG = "ZEE/Packages"
        private const val METHOD_CHANNEL = "zee/packages"
    }
}

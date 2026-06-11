package com.zeepowertoys.zee_power_toys.install

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import kotlin.math.roundToInt

/**
 * AppInstaller — installs an APK using the PackageInstaller session API (API 21+).
 *
 * Install path chosen (PackageInstaller session API):
 *   - Preferred over ACTION_VIEW / ACTION_INSTALL_PACKAGE because it does not
 *     require a FileProvider and works from a background context.
 *   - The session is created, the APK is streamed in, and the session is
 *     committed with a status BroadcastReceiver PendingIntent.
 *   - On emulators without unknown-sources granted, the system will show the
 *     install-confirmation dialog; the download itself completes regardless.
 *
 * Fallback (INTENT_ACTION_INSTALL — if PackageInstaller is unavailable):
 *   Uses ACTION_VIEW with a FileProvider URI (requires <provider> in manifest).
 */
object AppInstaller {

    private const val TAG = "ZEE/AppInstaller"

    // Status broadcast action sent by the PackageInstaller session.
    const val INSTALL_STATUS_ACTION = "com.zeepowertoys.zee_power_toys.INSTALL_STATUS"

    /**
     * Install the APK at [apkFile] via [PackageInstaller] session API.
     *
     * This is a blocking call — it writes the APK into the session stream
     * synchronously, then commits the session (which is non-blocking on the
     * install side; the system sends the INSTALL_STATUS broadcast when done).
     *
     * @throws Exception on I/O or session-creation failures.
     */
    fun installViaSession(context: Context, apkFile: File) {
        val packageInstaller = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        params.setAppPackageName(null)          // unknown before install
        params.setSize(apkFile.length())

        val sessionId = packageInstaller.createSession(params)
        Log.i(TAG, "PackageInstaller session created: id=$sessionId")

        packageInstaller.openSession(sessionId).use { session ->
            // Stream the APK bytes into the session.
            FileInputStream(apkFile).use { apkIn ->
                session.openWrite("package", 0, apkFile.length()).use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = apkIn.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                    }
                    session.fsync(out)
                }
            }

            // Commit — the system shows the install dialog (or auto-installs
            // if the caller is a device/session owner).
            val intentFlags = if (Build.VERSION.SDK_INT >= 31) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val statusIntent = Intent(INSTALL_STATUS_ACTION).apply {
                setPackage(context.packageName)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                sessionId,
                statusIntent,
                intentFlags,
            )
            session.commit(pendingIntent.intentSender)
            Log.i(TAG, "PackageInstaller session committed: id=$sessionId")
        }
    }

    /**
     * Fallback: launch install via ACTION_VIEW + FileProvider URI.
     *
     * Used when PackageInstaller is not available (defensive; normally always
     * available on API 21+).  Requires <uses-permission REQUEST_INSTALL_PACKAGES>
     * and a <provider> FileProvider in the manifest.
     */
    fun installViaIntent(context: Context, apkFile: File) {
        val uri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        Log.i(TAG, "Install intent launched for ${apkFile.name}")
    }
}

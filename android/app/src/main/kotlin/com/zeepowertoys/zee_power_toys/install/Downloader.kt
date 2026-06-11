package com.zeepowertoys.zee_power_toys.install

import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Downloader — streams an HTTP(S) URL to a local file, reporting progress.
 *
 * Uses only the standard-library HttpURLConnection — no new Gradle deps.
 * Follows HTTP 301/302 redirects (GitHub releases redirect to the CDN).
 * Progress is reported via [onProgress] callbacks: (bytesDownloaded, totalBytes).
 * [totalBytes] is -1 when the server does not send Content-Length.
 */
object Downloader {

    private const val TAG = "ZEE/Downloader"

    // Max redirect hops to prevent loops (GitHub uses 1 redirect).
    private const val MAX_REDIRECTS = 5

    /**
     * Download [url] to [destFile].
     *
     * @param onProgress callback invoked on each buffer read; bytesTotal=-1 if unknown.
     * @throws Exception on network error, HTTP ≥ 400, or I/O failure.
     */
    fun download(
        url: String,
        destFile: File,
        onProgress: (bytesDownloaded: Long, bytesTotal: Long) -> Unit,
    ) {
        var currentUrl = url
        var redirects = 0

        while (true) {
            val conn = URL(currentUrl).openConnection() as HttpURLConnection
            conn.connectTimeout = 15_000
            conn.readTimeout = 30_000
            conn.instanceFollowRedirects = false   // we handle redirects manually
            conn.setRequestProperty("Accept", "application/octet-stream")

            try {
                conn.connect()
                val code = conn.responseCode
                Log.d(TAG, "GET $currentUrl → HTTP $code")

                when {
                    code in 300..399 -> {
                        // Manual redirect follow — captures Location header.
                        val location = conn.getHeaderField("Location")
                            ?: throw IllegalStateException("HTTP $code but no Location header")
                        if (++redirects > MAX_REDIRECTS) {
                            throw IllegalStateException("Too many redirects (> $MAX_REDIRECTS)")
                        }
                        currentUrl = location
                        Log.d(TAG, "Redirect → $location")
                        continue    // re-open connection to new URL
                    }
                    code >= 400 -> {
                        throw IllegalStateException("HTTP error $code for $currentUrl")
                    }
                }

                val total = conn.contentLengthLong   // -1 if unknown
                var downloaded = 0L
                val buf = ByteArray(32 * 1024)       // 32 KiB read buffer

                // Ensure parent directory exists before writing.
                destFile.parentFile?.mkdirs()

                conn.inputStream.use { input ->
                    FileOutputStream(destFile).use { output ->
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            output.write(buf, 0, n)
                            downloaded += n
                            onProgress(downloaded, total)
                        }
                    }
                }
                Log.i(TAG, "Download complete: $downloaded bytes → ${destFile.absolutePath}")
                return  // success
            } finally {
                conn.disconnect()
            }
        }
    }
}

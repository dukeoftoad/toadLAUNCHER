package family.toad.launcher

import android.app.DownloadManager
import android.app.WallpaperManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.net.Uri
import android.os.Environment
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * toadLAUNCHER — the ONE Kotlin file, deliberately thin.
 *
 * Flutter owns every decision (indexing, family registry, update state
 * machine, version compare, settings, persistence). This adapter only
 * relays what the OS can do that Dart cannot: enumerate/launch apps,
 * usage stats, wallpaper, widget pinning, and the system DownloadManager
 * (whose process — not ours — holds the network, keeping the launcher
 * INTERNET-free).
 */
class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    private var pendingWallpaperResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(true)
                "versionInfo" -> result.success(versionInfo())
                "listApps" -> onExecutor(result) { listApps() }
                "launch" -> onMain(result) {
                    launch(call.argument<String>("packageId") ?: "")
                }
                "appDetails" -> onMain(result) {
                    openAppDetails(call.argument<String>("packageId") ?: "")
                }
                "uninstall" -> onMain(result) {
                    requestUninstall(call.argument<String>("packageId") ?: "")
                }
                "usageRecents" -> onExecutor(result) { usageRecents() }
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageAccessSettings" -> onMain(result) {
                    openUsageAccessSettings(); true
                }
                "setWallpaper" -> onExecutor(result) {
                    val png = call.argument<ByteArray>("png")
                    setWallpaperBytes(png)
                }
                "pickAndSetWallpaper" -> {
                    // Completes later from onActivityResult — never onMain.
                    pendingWallpaperResult = result
                    try {
                        startActivityForResult(pickIntent(), PICK_WALLPAPER)
                    } catch (e: Exception) {
                        pendingWallpaperResult = null
                        result.success(false)
                    }
                }
                "toadWidgets" -> onExecutor(result) {
                    toadWidgets(call.argument<List<String>>("familyIds") ?: emptyList())
                }
                "pinWidget" -> onMain(result) {
                    pinWidget(call.argument<String>("providerId") ?: "")
                }
                "checkLatestRelease" -> onExecutor(result) {
                    checkLatestRelease(call.argument<String>("repo") ?: "")
                }
                "enqueueApkDownload" -> onExecutor(result) {
                    enqueueApk(
                        call.argument<String>("url") ?: "",
                        call.argument<String>("fileName") ?: "toadlauncher-update.apk",
                        call.argument<String>("title") ?: "toadLAUNCHER update",
                    )
                }
                "downloadProgress" -> result.success(
                    downloadProgress((call.arguments as Map<*, *>)["id"] as Number)
                )
                "installDownloadedApk" -> onExecutor(result) {
                    installDownloadedApk(
                        (call.arguments as Map<*, *>)["id"] as Number,
                        (call.arguments as Map<*, *>)["expectedSha256"] as String?,
                    )
                }
                "openUrl" -> onMain(result) {
                    openUrl(call.argument<String>("url") ?: "")
                }
                else -> result.notImplemented()
            }
        }
    }

    // ------------------------------------------------------------------
    // plumbing

    private inline fun onMain(
        result: MethodChannel.Result,
        crossinline body: () -> Any?,
    ) {
        try {
            val value = body()
            result.success(value)
        } catch (e: Exception) {
            result.error("error", e.message, null)
        }
    }

    /** IllegalStateException.message doubles as the channel error code
     *  ("noAccess", "unavailable", "noApkAsset", "downloadUnavailable"). */
    private inline fun onExecutor(
        result: MethodChannel.Result,
        crossinline body: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = body()
                runOnUiThread { result.success(value) }
            } catch (e: IllegalStateException) {
                runOnUiThread { result.error(e.message ?: "error", e.message, null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("error", e.message, null) }
            }
        }
    }

    // ------------------------------------------------------------------
    // apps

    private fun versionInfo(): Map<String, Any> {
        val info = packageManager.getPackageInfo(packageName, 0)
        return mapOf(
            "versionName" to (info.versionName ?: "0.0.0"),
            "versionCode" to info.versionCode,
        )
    }

    private fun listApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolves = packageManager.queryIntentActivities(intent, 0)
        val out = mutableListOf<Map<String, Any?>>()
        for (info in resolves) {
            val pkg = info.activityInfo.packageName
            if (pkg == packageName) continue
            out.add(
                mapOf(
                    "packageId" to pkg,
                    "label" to (info.loadLabel(packageManager)?.toString() ?: pkg),
                    "iconPng" to iconPng(info.loadIcon(packageManager)),
                ),
            )
        }
        return out
    }

    /** Rasterize any drawable (incl. adaptive icons) to a 96 px PNG. */
    private fun iconPng(drawable: android.graphics.drawable.Drawable): ByteArray? {
        return try {
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            if (drawable is AdaptiveIconDrawable) {
                drawable.setBounds(0, 0, size, size)
                drawable.background?.draw(canvas)
                drawable.foreground?.draw(canvas)
            } else {
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
            val out = java.io.ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
            bitmap.recycle()
            out.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun launch(pkg: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openAppDetails(pkg: String): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun requestUninstall(pkg: String): Boolean {
        return try {
            startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
            true
        } catch (e: Exception) {
            false
        }
    }

    // ------------------------------------------------------------------
    // usage recents (special access, opt-in from Flutter)

    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            appOps.unsafeCheckOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName,
            ) == android.app.AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun openUsageAccessSettings() {
        try {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        } catch (e: Exception) {
            Log.w(TAG, "usage access settings unavailable", e)
        }
    }

    /** Package ids by most recent use over the last 7 days. */
    private fun usageRecents(): List<String> {
        if (!hasUsageAccess()) throw IllegalStateException("noAccess")
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 7L * 24 * 60 * 60 * 1000, now)
        val lastUse = HashMap<String, Long>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastUse[event.packageName] = event.timeStamp
            }
        }
        return lastUse.entries
            .sortedByDescending { it.value }
            .map { it.key }
    }

    // ------------------------------------------------------------------
    // wallpaper

    private fun setWallpaperBytes(png: ByteArray?): Boolean {
        if (png == null) return false
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return false
        val wm = WallpaperManager.getInstance(this)
        wm.setBitmap(bitmap)
        return true
    }

    private fun pickIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/*")
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_WALLPAPER) return
        val result = pendingWallpaperResult
        pendingWallpaperResult = null
        if (result == null) return
        if (data?.data == null) {
            result.success(false)
            return
        }
        val uri = data.data!!
        executor.execute {
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                val ok = setWallpaperBytes(bytes)
                runOnUiThread { result.success(ok) }
            } catch (e: Exception) {
                runOnUiThread { result.success(false) }
            }
        }
    }

    // ------------------------------------------------------------------
    // widgets

    private fun toadWidgets(familyIds: List<String>): List<Map<String, Any?>> {
        val awm = AppWidgetManager.getInstance(this)
        return awm.installedProviders
            .filter { it.packageName in familyIds }
            .map {
                mapOf(
                    "providerId" to ComponentName(it.packageName, it.name).flattenToString(),
                    "label" to (it.loadLabel(packageManager)?.toString() ?: it.packageName),
                    "packageName" to it.packageName,
                )
            }
    }

    private fun pinWidget(providerId: String): Boolean {
        return try {
            val cn = ComponentName.unflattenFromString(providerId) ?: return false
            AppWidgetManager.getInstance(this).requestPinAppWidget(cn, null, null)
        } catch (e: Exception) {
            false
        }
    }

    // ------------------------------------------------------------------
    // updates — through the system DownloadManager (network in the
    // system's process; this app stays INTERNET-free)

    private fun newDownload(
        url: String,
        title: String,
        fileName: String,
        toPublicDownloads: Boolean,
        mimeType: String,
    ): Long {
        val builder = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription("toadLAUNCHER")
            .setMimeType(mimeType)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
        if (toPublicDownloads) {
            builder.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
        } else {
            val dir = File(getExternalFilesDir(null), "updates").apply { mkdirs() }
            builder.setDestinationUri(Uri.fromFile(File(dir, fileName)))
        }
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return try {
            dm.enqueue(builder)
        } catch (e: Exception) {
            throw IllegalStateException("downloadUnavailable")
        }
    }

    private fun checkLatestRelease(repo: String): Map<String, Any?> {
        val jsonUrl = "https://api.github.com/repos/$repo/releases/latest"
        val temp = File(File(getExternalFilesDir(null), "updates").apply { mkdirs() }, "latest.json")
        temp.delete()
        val id = newDownload(jsonUrl, "toadLAUNCHER update check", temp.name, false, "application/json")
        val status = awaitDownload(id, timeoutMs = 25_000)
        if (status != DownloadManager.STATUS_SUCCESSFUL) throw IllegalStateException("unavailable")
        val text = readDownload(id)?.let { String(it) } ?: throw IllegalStateException("unavailable")
        temp.parentFile?.let { dir ->
            dir.listFiles()?.forEach { if (it.name.startsWith("latest.json")) it.delete() }
        }

        val json = JSONObject(text)
        val assets = json.optJSONArray("assets") ?: throw IllegalStateException("noApkAsset")
        var apkName: String? = null
        var apkUrl: String? = null
        var apkSize = 0L
        var shaAssetUrl: String? = null
        for (i in 0 until assets.length()) {
            val a = assets.getJSONObject(i)
            val name = a.optString("name")
            if (name.endsWith(".apk") && name.contains("toadlauncher")) {
                apkName = name
                apkUrl = a.optString("browser_download_url")
                apkSize = a.optLong("size")
            } else if (name.endsWith(".apk.sha256")) {
                shaAssetUrl = a.optString("browser_download_url")
            }
        }
        if (apkUrl.isNullOrEmpty()) throw IllegalStateException("noApkAsset")

        var sha256: String? = null
        if (shaAssetUrl != null) {
            try {
                val shaId = newDownload(
                    shaAssetUrl, "toadLAUNCHER checksum", "update.sha256", false, "text/plain",
                )
                if (awaitDownload(shaId, timeoutMs = 15_000) == DownloadManager.STATUS_SUCCESSFUL) {
                    sha256 = readDownload(shaId)?.let { String(it) }
                        ?.trim()
                        ?.split(Regex("\\s+"))
                        ?.firstOrNull()
                        ?.lowercase()
                }
            } catch (e: Exception) {
                // checksum optional — installer says so honestly
            }
        }

        return mapOf(
            "tagName" to json.optString("tag_name"),
            "htmlUrl" to json.optString("html_url"),
            "notes" to json.optString("body"),
            "apkName" to apkName,
            "apkUrl" to apkUrl,
            "apkSizeBytes" to apkSize,
            "sha256" to sha256,
        )
    }

    private fun enqueueApk(url: String, fileName: String, title: String): Long {
        return newDownload(url, title, fileName, true, "application/vnd.android.package-archive")
    }

    private fun downloadProgress(id: Number): Map<String, Any> {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(id.toLong())
        dm.query(query)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val bytesIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                val totalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                val status = when (cursor.getInt(statusIdx)) {
                    DownloadManager.STATUS_RUNNING, DownloadManager.STATUS_PENDING -> "running"
                    DownloadManager.STATUS_SUCCESSFUL -> "successful"
                    DownloadManager.STATUS_FAILED -> "failed"
                    DownloadManager.STATUS_PAUSED -> "paused"
                    else -> "unknown"
                }
                return mapOf(
                    "status" to status,
                    "bytesSoFar" to cursor.getLong(bytesIdx),
                    "totalBytes" to cursor.getLong(totalIdx),
                )
            }
        }
        return mapOf("status" to "unknown", "bytesSoFar" to 0L, "totalBytes" to -1L)
    }

    private fun awaitDownload(id: Long, timeoutMs: Long): Int {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val s = downloadProgress(id)["status"]
            if (s == "successful" || s == "failed") {
                val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                val q = DownloadManager.Query().setFilterById(id)
                dm.query(q)?.use { c ->
                    if (c.moveToFirst()) return c.getInt(c.getColumnIndex(DownloadManager.COLUMN_STATUS))
                }
            }
            Thread.sleep(400)
        }
        return DownloadManager.STATUS_FAILED
    }

    private fun readDownload(id: Long): ByteArray? {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(id)
        dm.query(query)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val uriStr = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI))
                if (uriStr != null) {
                    val uri = Uri.parse(uriStr)
                    val stream: InputStream? = when (uri.scheme) {
                        "file" -> File(uri.path ?: return null).inputStream()
                        "content" -> contentResolver.openInputStream(uri)
                        else -> null
                    }
                    return stream?.use { it.readBytes() }
                }
            }
        }
        return null
    }

    private fun installDownloadedApk(id: Number, expectedSha256: String?): String {
        val bytes = readDownload(id.toLong()) ?: return "failed"

        if (expectedSha256 != null) {
            val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
            val hex = digest.joinToString("") { "%02x".format(it) }
            if (!hex.equals(expectedSha256.lowercase(), ignoreCase = false)) return "checksumFailed"
        }

        if (!packageManager.canRequestPackageInstalls()) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                )
            } catch (e: Exception) {
                Log.w(TAG, "unknown-sources settings unavailable", e)
            }
            return "needsPermission"
        }

        try {
            val installer = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            val sessionId = installer.createSession(params)
            val session = installer.openSession(sessionId)
            try {
                val out = session.openWrite("toadlauncher.apk", 0, bytes.size.toLong())
                out.write(bytes)
                session.fsync(out)
                out.close()
                val intent = Intent(ACTION_INSTALL_STATUS).setPackage(packageName)
                val pi = android.app.PendingIntent.getBroadcast(
                    this, 0, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE,
                )
                session.commit(pi.intentSender)
            } catch (e: Exception) {
                session.abandon()
                throw e
            }
            return "started"
        } catch (e: Exception) {
            Log.w(TAG, "package installer failed", e)
            return "failed"
        }
    }

    private fun openUrl(url: String): Boolean {
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "toadLAUNCHER"
        private const val CHANNEL = "family.toad.launcher/device"
        private const val PICK_WALLPAPER = 7001
        private const val ACTION_INSTALL_STATUS = "family.toad.launcher.INSTALL_STATUS"
    }
}

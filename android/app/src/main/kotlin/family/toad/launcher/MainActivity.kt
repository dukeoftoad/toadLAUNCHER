package family.toad.launcher

import android.app.DownloadManager
import android.app.WallpaperManager
import android.app.role.RoleManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import java.util.concurrent.Executors

/**
 * toadLAUNCHER — the ONE Kotlin adapter file, deliberately thin.
 *
 * Flutter owns every decision (indexing, family registry, update state
 * machine, version compare, settings, persistence). This adapter only
 * relays what the OS can do that Dart cannot: enumerate/launch apps,
 * usage stats, wallpaper, widget HOSTING (AppWidgetHost + platform
 * views), default-home role, the notification shade, the lock screen
 * (through the accessibility service), app shortcuts, notification
 * counts, package-change events, battery status (the sticky
 * ACTION_BATTERY_CHANGED intent — level + plugged, nothing more), and
 * the system DownloadManager (whose process — not ours — holds the
 * network, keeping the launcher INTERNET-free).
 */
class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()

    /** Update ops own their thread: a release check can block for tens of
     *  seconds, and it must never delay app indexing or wallpaper work on
     *  [executor] — the v0.12 shared-thread design froze the whole channel
     *  behind a 25 s update check. */
    private val updateExecutor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    private var pendingWallpaperResult: MethodChannel.Result? = null
    private var widgetHost: AppWidgetHost? = null

    /** Live hosted views by appWidgetId — resize notifications (PLT-07)
     *  reach the real AppWidgetHostView through this map. */
    private val hostedViews = HashMap<Int, android.widget.FrameLayout>()

    /** Index refresh: installs / updates / removals land here live. */
    private val packageEvents = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val pkg = intent.data?.schemeSpecificPart ?: return
            channel?.invokeMethod(
                "packagesChanged",
                mapOf("action" to (intent.action ?: ""), "packageId" to pkg),
            )
        }
    }

    /** Battery ticks: the OS broadcasts on every level/plugged change and
     *  we relay the two facts Dart needs. No permission required. */
    private val batteryEvents = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_BATTERY_CHANGED) return
            channel?.invokeMethod("batteryChanged", batteryMap(intent))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        flutterEngine.platformViewsController.registry
            .registerViewFactory(VIEW_TYPE, ToadWidgetViewFactory(this))
        // Notification counts arrive from the listener service (same
        // process); relay them to Dart over the one channel.
        ToadNotificationListener.onCountsChanged = { counts ->
            channel?.invokeMethod("notificationCounts", counts)
        }
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
                "listHostableWidgets" -> onExecutor(result) { listHostableWidgets() }
                "hostWidget" -> onMain(result) {
                    hostWidget(call.argument<String>("providerId") ?: "")
                }
                "deleteHostedWidget" -> onMain(result) {
                    deleteHostedWidget(
                        (call.arguments as Map<*, *>)["appWidgetId"] as Number,
                    )
                }
                "isDefaultHome" -> onMain(result) { isDefaultHome() }
                "requestDefaultHome" -> onMain(result) { requestDefaultHome() }
                "openNotifications" -> onMain(result) { expandNotificationsPanel() }
                "lockScreen" -> onMain(result) { lockScreen() }
                "isLockServiceEnabled" -> onMain(result) { isLockServiceEnabled() }
                "openAccessibilitySettings" -> onMain(result) {
                    openAccessibilitySettings()
                }
                "hasNotificationAccess" -> onMain(result) { hasNotificationAccess() }
                "openNotificationListenerSettings" -> onMain(result) {
                    openNotificationListenerSettings()
                }
                "appShortcuts" -> onExecutor(result) {
                    appShortcuts(call.argument<String>("packageId") ?: "")
                }
                "startShortcut" -> onMain(result) {
                    startShortcut(
                        call.argument<String>("packageId") ?: "",
                        call.argument<String>("shortcutId") ?: "",
                    )
                }
                "shareApp" -> onMain(result) {
                    shareApp(call.argument<String>("packageId") ?: "")
                }
                "batteryStatus" -> result.success(
                    batteryStatus()
                )
                "checkLatestRelease" -> onUpdateExecutor(result) {
                    checkLatestRelease(call.argument<String>("repo") ?: "")
                }
                "enqueueApkDownload" -> onUpdateExecutor(result) {
                    enqueueApk(
                        call.argument<String>("url") ?: "",
                        call.argument<String>("fileName") ?: "toadlauncher-update.apk",
                        call.argument<String>("title") ?: "toadLAUNCHER update",
                    )
                }
                "downloadProgress" -> onUpdateExecutor(result) {
                    downloadProgress((call.arguments as Map<*, *>)["id"] as Number)
                }
                "installDownloadedApk" -> onUpdateExecutor(result) {
                    installDownloadedApk(
                        (call.arguments as Map<*, *>)["id"] as Number,
                        (call.arguments as Map<*, *>)["expectedSha256"] as String?,
                    )
                }
                "openUrl" -> onMain(result) {
                    openUrl(call.argument<String>("url") ?: "")
                }
                // SEC-02: verify the release's detached update signature.
                "verifyUpdateSignature" -> onMain(result) {
                    verifyUpdateSignature(
                        call.argument<String>("message") ?: "",
                        call.argument<String>("signature") ?: "",
                    )
                }
                // REL-01: local crash-log + diagnostics support.
                "appFilesDir" -> result.success(filesDir.absolutePath)
                "signingCertFingerprint" -> onMain(result) { signingCertFingerprint() }
                "openHomeSettings" -> onMain(result) { openHomeSettings() }
                "shareDiagnosticsFile" -> onMain(result) {
                    shareDiagnosticsFile(call.argument<String>("path") ?: "")
                }
                // PLT-01: the ask flow adapts to the platform version
                // (Restricted Settings arrive on Android 13).
                "osSdkInt" -> result.success(Build.VERSION.SDK_INT)
                // PLT-07: tell a hosted widget its new size (responsive
                // widgets re-render when the span changes).
                "resizeHostedWidget" -> onMain(result) {
                    resizeHostedWidget(
                        (call.arguments as Map<*, *>)["appWidgetId"] as Number,
                        (call.arguments as Map<*, *>)["widthDp"] as Number,
                        (call.arguments as Map<*, *>)["heightDp"] as Number,
                    )
                }
                // PLT-03: real screenshot through the lock service.
                "takeScreenshot" -> onMain(result) { takeScreenshot() }
                else -> result.notImplemented()
            }
        }
    }

    // ------------------------------------------------------------------
    // lifecycle — widget host + package events

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ToadNotificationListener.startWatching()
        sweepStaleDownloads()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_EXTERNAL_APPLICATIONS_AVAILABLE)
            addAction(Intent.ACTION_EXTERNAL_APPLICATIONS_UNAVAILABLE)
            addDataScheme("package")
        }
        if (Build.VERSION.SDK_INT >= 33) {
            // Protected system broadcasts — NOT_EXPORTED still receives
            // them; other apps can never spoof into this receiver.
            registerReceiver(packageEvents, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverOption")
            registerReceiver(packageEvents, filter)
        }
        // ACTION_BATTERY_CHANGED is a sticky, protected system broadcast —
        // no permission, no export concerns (it can only come from the OS).
        val batteryFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(batteryEvents, batteryFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverOption")
            registerReceiver(batteryEvents, batteryFilter)
        }
    }

    override fun onStart() {
        super.onStart()
        // Host must listen before createView so widgets receive updates.
        ensureWidgetHost().startListening()
    }

    override fun onStop() {
        widgetHost?.stopListening()
        super.onStop()
    }

    override fun onDestroy() {
        ToadNotificationListener.onCountsChanged = null
        try {
            unregisterReceiver(packageEvents)
        } catch (e: Exception) {
            Log.w(TAG, "package events receiver not registered", e)
        }
        try {
            unregisterReceiver(batteryEvents)
        } catch (e: Exception) {
            Log.w(TAG, "battery events receiver not registered", e)
        }
        executor.shutdown()
        updateExecutor.shutdown()
        super.onDestroy()
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

    /** The update twin of [onExecutor] — same error contract, own thread. */
    private inline fun onUpdateExecutor(
        result: MethodChannel.Result,
        crossinline body: () -> Any?,
    ) {
        updateExecutor.execute {
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

    // ------------------------------------------------------------------
    // battery (v0.12) — level + plugged from the sticky battery intent.
    // The launcher keeps NO battery history here: sampling, drain rate
    // and the low-battery guard are all Dart (Flutter owns decisions).
    // ------------------------------------------------------------------

    /** The two facts Dart needs from an ACTION_BATTERY_CHANGED intent. */
    private fun batteryMap(intent: Intent): Map<String, Any> {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        val pct = if (level >= 0 && scale > 0) (level * 100 / scale) else -1
        return mapOf(
            "level" to pct,
            "charging" to (plugged != 0),
            "full" to (status == BatteryManager.BATTERY_STATUS_FULL),
        )
    }

    private fun batteryStatus(): Map<String, Any> {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        return if (intent != null) batteryMap(intent) else mapOf(
            "level" to -1,
            "charging" to false,
            "full" to false,
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

    /** Rasterize any drawable (incl. adaptive icons) to a PNG. */
    private fun iconPng(
        drawable: android.graphics.drawable.Drawable,
        size: Int = 96,
    ): ByteArray? {
        return try {
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
            .filter { it.provider.packageName in familyIds }
            .map {
                val cn = it.provider
                mapOf(
                    "providerId" to cn.flattenToString(),
                    "label" to (it.loadLabel(packageManager)?.toString() ?: cn.packageName),
                    "packageName" to cn.packageName,
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
    // system's process; this app stays INTERNET-free). Ported to the
    // toadFILES flow that actually works on-device: app-private
    // destination + DownloadManager content URI + plain install intent.

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
            // The user tapped a button (or opted into the auto-check):
            // honor metered networks too — Wi-Fi-only queuing is how
            // "stuck at 0%" bugs are born.
            .setAllowedOverMetered(true)
        if (toPublicDownloads) {
            builder.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
        } else {
            builder.setDestinationUri(Uri.fromFile(File(appPrivateUpdatesDir(), fileName)))
        }
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return try {
            dm.enqueue(builder)
        } catch (e: Exception) {
            throw IllegalStateException("downloadUnavailable")
        }
    }

    /** App-private updates dir — never public Downloads. */
    private fun appPrivateUpdatesDir(): File =
        File(getExternalFilesDir(null), "updates").apply { mkdirs() }

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
        var anyApkName: String? = null
        var anyApkUrl: String? = null
        var anyApkSize = 0L
        var shaAssetUrl: String? = null
        for (i in 0 until assets.length()) {
            val a = assets.getJSONObject(i)
            val name = a.optString("name")
            if (name.endsWith(".apk.sha256")) {
                shaAssetUrl = a.optString("browser_download_url")
                continue
            }
            if (!name.endsWith(".apk", ignoreCase = true)) continue
            if (anyApkUrl == null) {
                anyApkName = name
                anyApkUrl = a.optString("browser_download_url")
                anyApkSize = a.optLong("size")
            }
            // Prefer the asset that names the launcher, but never depend on
            // exact naming — a renamed asset must not break the update
            // (the old contains("toadlauncher") filter threw noApkAsset
            // whenever the release asset carried a different name).
            if (apkUrl == null && name.contains("launcher", ignoreCase = true)) {
                apkName = name
                apkUrl = a.optString("browser_download_url")
                apkSize = a.optLong("size")
            }
        }
        if (apkUrl.isNullOrEmpty()) {
            apkName = anyApkName
            apkUrl = anyApkUrl
            apkSize = anyApkSize
        }
        if (apkUrl.isNullOrEmpty()) throw IllegalStateException("noApkAsset")

        var sha256: String? = null
        var sig: String? = null
        var sigAssetUrl: String? = null
        for (i in 0 until assets.length()) {
            val a = assets.getJSONObject(i)
            val name = a.optString("name")
            if (name.endsWith(".apk.sha256")) {
                shaAssetUrl = a.optString("browser_download_url")
                continue
            }
            if (name.endsWith(".apk.sig")) {
                sigAssetUrl = a.optString("browser_download_url")
                continue
            }
            if (!name.endsWith(".apk", ignoreCase = true)) continue
            if (anyApkUrl == null) {
                anyApkName = name
                anyApkUrl = a.optString("browser_download_url")
                anyApkSize = a.optLong("size")
            }
            // Prefer the asset that names the launcher, but never depend on
            // exact naming — a renamed asset must not break the update
            // (the old contains("toadlauncher") filter threw noApkAsset
            // whenever the release asset carried a different name).
            if (apkUrl == null && name.contains("launcher", ignoreCase = true)) {
                apkName = name
                apkUrl = a.optString("browser_download_url")
                apkSize = a.optLong("size")
            }
        }
        if (apkUrl.isNullOrEmpty()) {
            apkName = anyApkName
            apkUrl = anyApkUrl
            apkSize = anyApkSize
        }
        if (apkUrl.isNullOrEmpty()) throw IllegalStateException("noApkAsset")

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
        if (sigAssetUrl != null) {
            try {
                val sigId = newDownload(
                    sigAssetUrl, "toadLAUNCHER signature", "update.sig", false, "application/octet-stream",
                )
                if (awaitDownload(sigId, timeoutMs = 15_000) == DownloadManager.STATUS_SUCCESSFUL) {
                    sig = readDownload(sigId)?.let { String(it) }?.trim()
                }
            } catch (e: Exception) {
                // Signature missing → the Dart engine refuses the update
                // (honest error, release-page handoff).
            }
        }

        return mapOf(
            "tagName" to json.optString("tag_name"),
            "htmlUrl" to json.optString("html_url").ifBlank { "https://github.com/$repo/releases" },
            "notes" to json.optString("body").replace("\r\n", "\n").ifBlank { null },
            "apkName" to apkName,
            "apkUrl" to apkUrl,
            "apkSizeBytes" to apkSize,
            "sha256" to sha256,
            "sig" to sig,
        )
    }

    /** APK signing certificates we accept for updates: the lineage root
     *  (v0.9 → v1.0 key, retired, no rollback capability) and the current
     *  key. Anything else is an impersonation attempt. */
    private val expectedApkCertSha256 = setOf(
        "6ae99f0bb980b0cb6bc707bff4a6659ade18947e9db203946193c514c200702a",
        "5fdadde01fdf2517a70aac86f315887cb79b74a0d478796f0d4bf40ccb7ac6b6",
    )

    /** SHA-256 hex of the APK's signing certificate, or null when it
     *  cannot be parsed. Streams to a cache temp file because
     *  getPackageArchiveInfo needs a filesystem path. */
    private fun apkSignerCertHex(uri: Uri): String? {
        return try {
            val tmp = File(cacheDir, "verify-update.apk")
            contentResolver.openInputStream(uri)?.use { input ->
                tmp.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            val info = packageManager.getPackageArchiveInfo(
                tmp.absolutePath,
                PackageManager.GET_SIGNATURES,
            )
            tmp.delete()
            val sig = info?.signatures?.firstOrNull() ?: return null
            sig.toByteArray().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Log.w(TAG, "APK cert parse failed", e)
            null
        }
    }

    /** APK → the APP-PRIVATE updates dir (toadFILES' proven layout). From
     *  here the initiating app can always read the job back through
     *  DownloadManager's own content URI — zero storage permissions, every
     *  Android from 7 to 15. Public Downloads + COLUMN_LOCAL_URI was the
     *  v0.12 break: scoped storage made that file unreadable to us, so
     *  every install handoff died as "failed". The stale destination is
     *  deleted before enqueue because DownloadManager refuses to overwrite
     *  an existing file — this is what makes a retry actually re-download. */
    private fun enqueueApk(url: String, fileName: String, title: String): Long {
        val name = fileName.takeLastWhile { it != '/' && it != '\\' }
            .ifBlank { "toadlauncher-update.apk" }
        val dest = File(appPrivateUpdatesDir(), name)
        if (dest.exists() && !dest.delete()) throw IllegalStateException("downloadUnavailable")
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return try {
            dm.enqueue(
                DownloadManager.Request(Uri.parse(url))
                    .setTitle(title)
                    .setDescription("toadLAUNCHER update")
                    .setMimeType("application/vnd.android.package-archive")
                    .setNotificationVisibility(
                        DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                    )
                    .setAllowedOverMetered(true)
                    .setDestinationUri(Uri.fromFile(dest)),
            )
        } catch (e: Exception) {
            throw IllegalStateException("downloadUnavailable")
        }
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
        // Preferred: the job's own content URI — always readable by the app
        // that enqueued it, whatever the destination type or Android version.
        try {
            dm.openDownloadedFile(id)?.use { pfd ->
                return android.os.ParcelFileDescriptor.AutoCloseInputStream(pfd)
                    .use { it.readBytes() }
            }
        } catch (e: Exception) {
            Log.w(TAG, "openDownloadedFile fell back to local uri", e)
        }
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

    /** SHA-256 gate (streamed, never the whole APK in RAM), then the
     *  toadFILES install handoff: the job's own DownloadManager content URI
     *  handed to the system installer via ACTION_VIEW with a read grant.
     *  The v0.12 PackageInstaller-session path is gone — it buffered the
     *  whole APK, never registered its status receiver, died quietly on
     *  ROMs that refuse mutable PendingIntents, and referenced
     *  PackageInstaller WITHOUT its import (the committed tree could not
     *  even compile — the true "update is broken" root).
     *
     *  SEC-02: the APK's signing certificate must be one of ours (the
     *  lineage root or the current key) — a correctly-hashed APK signed by
     *  anyone else is rejected before the installer ever sees it. */
    private fun installDownloadedApk(id: Number, expectedSha256: String?): String {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val uri = dm.getUriForDownloadedFile(id.toLong()) ?: return "failed"

        if (expectedSha256 != null) {
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                contentResolver.openInputStream(uri)?.use { input ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        digest.update(buf, 0, n)
                    }
                } ?: return "failed"
                val hex = digest.digest().joinToString("") { "%02x".format(it) }
                if (!hex.equals(expectedSha256.lowercase(), ignoreCase = true)) {
                    return "checksumFailed"
                }
            } catch (e: Exception) {
                Log.w(TAG, "checksum stream failed", e)
                return "failed"
            }
        }

        // SEC-02: signer certificate gate.
        val certHex = apkSignerCertHex(uri)
        if (certHex == null || certHex !in expectedApkCertSha256) {
            Log.w(TAG, "update APK signer certificate mismatch")
            return "wrongCertificate"
        }

        // "Install unknown apps" gate — open the exact settings toggle;
        // the banner's retry row resumes after the flip (toadFILES flow).
        val canInstall = try {
            packageManager.canRequestPackageInstalls()
        } catch (e: Exception) {
            false
        }
        if (!canInstall) {
            return try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                )
                "needsPermission"
            } catch (e: Exception) {
                Log.w(TAG, "unknown-sources settings unavailable", e)
                "needsPermission"
            }
        }

        return try {
            val install = Intent(Intent.ACTION_VIEW).apply {
                setDataAndTypeAndNormalize(uri, "application/vnd.android.package-archive")
                clipData = android.content.ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                // The handoff can complete while the launcher is backgrounded;
                // NEW_TASK keeps the start legal from any context.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(install)
            "started"
        } catch (e: Exception) {
            Log.w(TAG, "installer handoff failed", e)
            "failed"
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

    // ------------------------------------------------------------------
    // SEC-02 — the update trust chain. The release's detached signature
    // (ECDSA P-256 over "tagName|sha256|assetName") is verified with the
    // UPDATE-signing public key embedded below — a separate key from the
    // APK signing key, held only in CI secrets. A tampered hash, a
    // tampered signature or a wrong-asset swap all fail here, BEFORE the
    // banner ever says "update available".
    // ------------------------------------------------------------------

    /** The update-signing public key (X.509 SPKI, base64). Private half
     *  lives only in the repo's CI secrets. Fingerprint printed in
     *  SECURITY.md. */
    private val updateSigningPublicKeyB64 =
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEaQeJVytfG0WM4Y4W1w6kBq37zee6cyVJ9Lt" +
            "/EqYxe1UdP4g95Ty9KHv21TiDbYyChWODrDAjXxvrNJpEjY0Vsg=="

    fun verifyUpdateSignature(message: String, signatureBase64: String): Boolean {
        return try {
            val keyBytes = Base64.getDecoder().decode(updateSigningPublicKeyB64)
            val publicKey = KeyFactory.getInstance("EC")
                .generatePublic(X509EncodedKeySpec(keyBytes))
            val sigBytes = Base64.getDecoder().decode(signatureBase64.trim())
            val verifier = Signature.getInstance("SHA256withECDSA")
            verifier.initVerify(publicKey)
            verifier.update(message.toByteArray(Charsets.UTF_8))
            verifier.verify(sigBytes)
        } catch (e: Exception) {
            Log.w(TAG, "update signature verification failed", e)
            false
        }
    }

    /** SHA-256 hex of our own signing certificate (Settings → About shows
     *  it so users can cross-check against SECURITY.md). */
    private fun signingCertFingerprint(): String? {
        return try {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            val sig = info.signatures?.firstOrNull() ?: return null
            sig.toByteArray().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    /** SEC-03: delete update leftovers older than a week — the updates dir
     *  never accumulates stale APKs (install handoffs that never completed,
     *  old versions after a successful update). */
    private fun sweepStaleDownloads() {
        executor.execute {
            try {
                val dir = appPrivateUpdatesDir()
                val week = 7L * 24 * 60 * 60 * 1000
                val now = System.currentTimeMillis()
                dir.listFiles()?.forEach { f ->
                    if (now - f.lastModified() > week) f.delete()
                }
            } catch (e: Exception) {
                Log.w(TAG, "update sweep failed", e)
            }
        }
    }

    /** REL-01: the system Home picker (safe mode's escape hatch). */
    private fun openHomeSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
            true
        } catch (e: Exception) {
            false
        }
    }

    /** REL-01: share the local crash log via the system sheet — the file
     *  never leaves the phone unless the user chooses a target. Shared as
     *  plain text (the log is text), so no file provider is needed. */
    private fun shareDiagnosticsFile(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            // Bound the payload: share the tail (most recent entries).
            val bytes = file.readBytes()
            val text = if (bytes.size > 200_000) {
                "…(older entries trimmed)\n" + String(bytes, bytes.size - 200_000, 200_000, Charsets.UTF_8)
            } else {
                String(bytes, Charsets.UTF_8)
            }
            val send = Intent(Intent.ACTION_SEND)
                .setType("text/plain")
                .putExtra(Intent.EXTRA_SUBJECT, "toadLAUNCHER crash log")
                .putExtra(Intent.EXTRA_TEXT, text)
            startActivity(Intent.createChooser(send, "Share crash log"))
            true
        } catch (e: Exception) {
            false
        }
    }

    // PLT-07: forward a size change to the real AppWidgetHostView so
    // responsive widgets re-render at the right size.
    private fun resizeHostedWidget(appWidgetId: Number, widthDp: Number, heightDp: Number): Boolean {
        return try {
            val container = hostedViews[appWidgetId.toInt()] ?: return false
            val view = container.getChildAt(0) as? android.appwidget.AppWidgetHostView
                ?: return false
            val options = android.os.Bundle()
            view.updateAppWidgetSize(
                options,
                widthDp.toInt(),
                heightDp.toInt(),
                widthDp.toInt(),
                heightDp.toInt(),
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "resizeHostedWidget failed", e)
            false
        }
    }

    /** PLT-03: the two-finger screenshot, finally real — the accessibility
     *  service's global action (API 28+), same consent as the lock. */
    private fun takeScreenshot(): Boolean {
        val service = ToadLockService.instance ?: return false
        return try {
            service.takeScreenshot()
        } catch (e: Exception) {
            false
        }
    }

    // ------------------------------------------------------------------
    // widget HOSTING — AppWidgetHost owns ids; views render through the
    // "toad-widget-host" platform view (hybrid composition on the Dart
    // side). Binding needs the default-home role; the UI explains that.

    private fun ensureWidgetHost(): AppWidgetHost {
        var host = widgetHost
        if (host == null) {
            host = AppWidgetHost(applicationContext, WIDGET_HOST_ID)
            widgetHost = host
        }
        return host
    }

    /** Every widget provider on the phone — the picker's full shelf. */
    private fun listHostableWidgets(): List<Map<String, Any?>> {
        val awm = AppWidgetManager.getInstance(this)
        val out = mutableListOf<Map<String, Any?>>()
        for (info in awm.installedProviders) {
            val cn = info.provider
            out.add(
                mapOf(
                    "providerId" to cn.flattenToString(),
                    "label" to (info.loadLabel(packageManager)?.toString() ?: cn.packageName),
                    "packageName" to cn.packageName,
                    "previewPng" to previewPng(info),
                    "minWidth" to info.minWidth,
                    "minHeight" to info.minHeight,
                ),
            )
        }
        return out
    }

    private fun previewPng(info: AppWidgetProviderInfo): ByteArray? {
        return try {
            val drawable = info.loadPreviewImage(this, 0) ?: info.loadIcon(this, 0)
                ?: return null
            iconPng(drawable, 144)
        } catch (e: Exception) {
            null
        }
    }

    /** Allocate + bind. Returns the bound id, or null when refused
     *  (refusal means "not the default home" — the UI says exactly that). */
    private fun hostWidget(providerId: String): Int? {
        return try {
            val cn = ComponentName.unflattenFromString(providerId) ?: return null
            val awm = AppWidgetManager.getInstance(this)
            val host = ensureWidgetHost()
            val id = host.allocateAppWidgetId()
            if (awm.bindAppWidgetIdIfAllowed(id, cn)) id else {
                host.deleteAppWidgetId(id)
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "hostWidget failed", e)
            null
        }
    }

    private fun deleteHostedWidget(appWidgetId: Number): Boolean {
        return try {
            ensureWidgetHost().deleteAppWidgetId(appWidgetId.toInt())
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Called by the platform-view factory (main thread) to inflate the
     *  real AppWidgetHostView into [container]. The container is tracked
     *  so resize notifications (PLT-07) reach the live view. */
    fun renderWidgetInto(container: FrameLayout, appWidgetId: Int?, providerId: String?) {
        val awm = AppWidgetManager.getInstance(this)
        val bound = appWidgetId?.let { awm.getAppWidgetInfo(it) }
        // API 37 removed AppWidgetProviderInfo.packageName/name — resolve
        // unbound-id fallbacks through the provider ComponentName.
        val providerInfo = bound ?: providerId?.let { pid ->
            ComponentName.unflattenFromString(pid)?.let { cn ->
                awm.installedProviders.firstOrNull { it.provider == cn }
            }
        }
        if (appWidgetId == null || providerInfo == null) {
            container.addView(placeholderView("Widget gone — remove and add again"))
            return
        }
        try {
            val view = ensureWidgetHost().createView(this, appWidgetId, providerInfo)
            view.setPadding(0, 0, 0, 0)
            container.addView(
                view,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            if (appWidgetId != null) hostedViews[appWidgetId] = container
        } catch (e: Exception) {
            Log.w(TAG, "widget render failed", e)
            container.addView(placeholderView("This widget could not load"))
        }
    }

    private fun placeholderView(text: String): TextView {
        val tv = TextView(this)
        tv.text = text
        tv.setPadding(24, 24, 24, 24)
        return tv
    }

    /** A platform view went away — stop tracking its container. */
    fun forgetHostedView(appWidgetId: Int?) {
        if (appWidgetId != null) hostedViews.remove(appWidgetId)
    }

    // ------------------------------------------------------------------
    // launcher-grade system integrations

    private fun isDefaultHome(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val rm = getSystemService(RoleManager::class.java)
                rm != null && rm.isRoleHeld(RoleManager.ROLE_HOME)
            } else {
                val resolved = packageManager.resolveActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
                    PackageManager.MATCH_DEFAULT_ONLY,
                )
                resolved?.activityInfo?.packageName == packageName
            }
        } catch (e: Exception) {
            false
        }
    }

    /** Opens the system role dialog (API 29+) or the home settings page. */
    private fun requestDefaultHome(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val rm = getSystemService(RoleManager::class.java) ?: return false
                if (!rm.isRoleAvailable(RoleManager.ROLE_HOME)) return false
                startActivity(rm.createRequestRoleIntent(RoleManager.ROLE_HOME))
                true
            } else {
                startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    /** Pulls the real notification shade. Primary: the hidden
     *  StatusBarManager call every third-party launcher uses. Fallback
     *  (PLT-02): the accessibility service's global action when the
     *  hidden API is blocked — same opt-in consent as the lock, honest
     *  failure when neither route exists. */
    private fun expandNotificationsPanel(): Boolean {
        try {
            val sbs = getSystemService(Context.STATUS_BAR_SERVICE) ?: return fallbackShade()
            Class.forName("android.app.StatusBarManager")
                .getMethod("expandNotificationsPanel")
                .invoke(sbs)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "shade expand unavailable, trying accessibility fallback", e)
            return fallbackShade()
        }
    }

    private fun fallbackShade(): Boolean {
        val service = ToadLockService.instance ?: return false
        return try {
            service.pullNotificationsPanel()
        } catch (e: Exception) {
            false
        }
    }

    /** Lock via the accessibility service (API 28+ global action). */
    private fun lockScreen(): Boolean {
        val service = ToadLockService.instance ?: return false
        return try {
            service.lockNow()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isLockServiceEnabled(): Boolean {
        return try {
            val enabled = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            enabled.contains(packageName)
        } catch (e: Exception) {
            false
        }
    }

    private fun openAccessibilitySettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            if (Build.VERSION.SDK_INT >= 26) {
                intent.putExtra(
                    Intent.EXTRA_COMPONENT_NAME,
                    ComponentName(this, ToadLockService::class.java),
                )
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun hasNotificationAccess(): Boolean {
        return try {
            val enabled = Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            enabled.split(":").any { it.contains(packageName) }
        } catch (e: Exception) {
            false
        }
    }

    private fun openNotificationListenerSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Dynamic + manifest + pinned shortcuts of one app. Only the default
     *  home is allowed to query them — an empty list says "nothing to
     *  show". */
    private fun appShortcuts(pkg: String): List<Map<String, Any?>> {
        if (!isDefaultHome()) return emptyList()
        return try {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val query = LauncherApps.ShortcutQuery()
                .setPackage(pkg)
                .setQueryFlags(
                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED,
                )
            val shortcuts = la.getShortcuts(query, Process.myUserHandle()) ?: emptyList()
            shortcuts.take(4).map { s ->
                mapOf(
                    "id" to s.id,
                    "label" to (
                        s.shortLabel?.toString()
                            ?: s.longLabel?.toString()
                            ?: pkg
                        ),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun startShortcut(pkg: String, shortcutId: String): Boolean {
        return try {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            la.startShortcut(pkg, shortcutId, null, null, Process.myUserHandle())
            true
        } catch (e: Exception) {
            Log.w(TAG, "startShortcut failed", e)
            false
        }
    }

    /** The old demo toast becomes a real ACTION_SEND chooser. */
    private fun shareApp(pkg: String): Boolean {
        return try {
            val label = packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0),
            )
            val send = Intent(Intent.ACTION_SEND)
                .setType("text/plain")
                .putExtra(
                    Intent.EXTRA_TEXT,
                    "\"$label\" is on my toadLAUNCHER home ($pkg)",
                )
            startActivity(Intent.createChooser(send, "Share via"))
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val TAG = "toadLAUNCHER"
        private const val CHANNEL = "family.toad.launcher/device"
        private const val PICK_WALLPAPER = 7001
        private const val WIDGET_HOST_ID = 0x70AD
        const val VIEW_TYPE = "toad-widget-host"
    }
}

/**
 * The platform-view bridge — Flutter embeds real home-screen widgets
 * through this factory (hybrid composition from Dart). Creation params:
 *   appWidgetId  Int   — the AppWidgetHost id Dart persisted
 *   providerId   String — flat ComponentName fallback
 */
class ToadWidgetViewFactory(
    private val activity: MainActivity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Suppress("UNCHECKED_CAST")
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<String, Any?> ?: emptyMap()
        return ToadWidgetPlatformView(activity, params)
    }
}

class ToadWidgetPlatformView(
    private val activity: MainActivity,
    params: Map<String, Any?>,
) : PlatformView {

    private val container = FrameLayout(activity)
    private val appWidgetId = (params["appWidgetId"] as? Number)?.toInt()

    init {
        activity.renderWidgetInto(
            container,
            appWidgetId,
            params["providerId"] as? String,
        )
    }

    override fun getView(): View = container

    override fun dispose() {
        activity.forgetHostedView(appWidgetId)
        container.removeAllViews()
    }
}

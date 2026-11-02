package com.keshabstudios.goodbyeapps

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.storage.StorageManager
import android.provider.Settings
import android.util.LruCache
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val methodChannelName = "goodbye_apps/native"
    private val eventChannelName = "goodbye_apps/events"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Icon bytes by package, weighted by size. `listApps` no longer ships
     * icons (docs/07): 200 PNG encodes plus a 1.5 MB transfer was what made
     * the first frame slow, so rows ask for their own icon on demand.
     */
    private val iconCache = object : LruCache<String, ByteArray>(8 * 1024 * 1024) {
        // sizeOf is measured in the same unit as the budget above: bytes.
        override fun sizeOf(key: String, value: ByteArray): Int = value.size
    }

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listApps" -> executor.execute {
                        try {
                            val apps = loadApps()
                            mainHandler.post { result.success(apps) }
                        } catch (t: Throwable) {
                            mainHandler.post { result.error("list_failed", t.message, null) }
                        }
                    }

                    "uninstall" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("bad_args", "package is required", null)
                        } else {
                            result.success(uninstall(pkg))
                        }
                    }

                    "launch" -> {
                        val pkg = call.argument<String>("package")
                        result.success(pkg != null && launch(pkg))
                    }

                    "appInfo" -> {
                        val pkg = call.argument<String>("package")
                        result.success(pkg != null && openAppInfo(pkg))
                    }

                    "playStore" -> {
                        val pkg = call.argument<String>("package")
                        result.success(pkg != null && openPlayStore(pkg))
                    }

                    "shareApp" -> {
                        val text = call.argument<String>("text") ?: ""
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        result.success(startActivitySafely(Intent.createChooser(intent, null)))
                    }

                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        val intent = if (url != null) Intent(Intent.ACTION_VIEW, Uri.parse(url)) else null
                        result.success(intent != null && startActivitySafely(intent))
                    }

                    "getIcon" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("bad_args", "package is required", null)
                        } else {
                            // getApplicationIcon touches disk: keep it off the main thread.
                            executor.execute {
                                val bytes = loadIcon(pkg)
                                mainHandler.post { result.success(bytes) }
                            }
                        }
                    }

                    "addShortcut" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("bad_args", "package is required", null)
                        } else {
                            executor.execute {
                                val ok = addShortcut(pkg)
                                mainHandler.post { result.success(ok) }
                            }
                        }
                    }

                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "usageAccessSettings" -> result.success(
                        startActivitySafely(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    )

                    "getSizeBreakdown" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("bad_args", "package is required", null)
                        } else {
                            // queryStatsForPackage is a disk query: off the main thread.
                            executor.execute {
                                val breakdown = sizeBreakdown(pkg)
                                mainHandler.post { result.success(breakdown) }
                            }
                        }
                    }

                    "freeMemory" -> result.success(freeMemory())

                    "appVersion" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        result.success(mapOf(
                            "versionName" to (info.versionName ?: ""),
                            "versionCode" to packageInfoVersionCode(info)
                        ))
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    registerPackageReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterPackageReceiver()
                }
            })
    }

    override fun onDestroy() {
        unregisterPackageReceiver()
        super.onDestroy()
    }

    // ---------------------------------------------------------------- listing

    private fun loadApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val infos: List<ApplicationInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

        val out = ArrayList<Map<String, Any?>>(infos.size)
        for (ai in infos) {
            if (ai.packageName == packageName) continue
            val pkgInfo = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getPackageInfo(ai.packageName, PackageManager.PackageInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(ai.packageName, 0)
                }
            } catch (t: Throwable) {
                null
            }

            out.add(mapOf(
                "packageName" to ai.packageName,
                "label" to pm.getApplicationLabel(ai).toString(),
                "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "sizeBytes" to apkSize(ai),
                "firstInstallTime" to (pkgInfo?.firstInstallTime ?: 0L),
                "lastUpdateTime" to (pkgInfo?.lastUpdateTime ?: 0L),
                "versionName" to (pkgInfo?.versionName ?: ""),
                "versionCode" to (if (pkgInfo != null) packageInfoVersionCode(pkgInfo) else 0L)
            ))
        }
        return out
    }

    private fun packageInfoVersionCode(info: android.content.pm.PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun apkSize(ai: ApplicationInfo): Long {
        var total = 0L
        try {
            ai.sourceDir?.let { total += File(it).length() }
            ai.splitSourceDirs?.forEach { path -> total += File(path).length() }
        } catch (_: Throwable) {
        }
        return total
    }

    private fun loadIcon(pkg: String): ByteArray? {
        iconCache.get(pkg)?.let { return it }
        val bytes = try {
            drawableToPng(packageManager.getApplicationIcon(pkg))
        } catch (_: Throwable) {
            null
        }
        // Cache "no icon" as an empty array, so a row that cannot be drawn
        // does not retry on every scroll.
        iconCache.put(pkg, bytes ?: ByteArray(0))
        return bytes
    }

    private fun drawableToPng(drawable: Drawable): ByteArray? {
        return try {
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 96
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 96
            val bitmap: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bmp ->
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                }
            }
            val scaled = if (bitmap.width > 144 || bitmap.height > 144) {
                Bitmap.createScaledBitmap(bitmap, 144, 144, true)
            } else {
                bitmap
            }
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (_: Throwable) {
            null
        }
    }

    /**
     * Usage access is a special permission the user grants in Settings, never a
     * runtime dialog — so every caller must treat null as "not available".
     */
    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(AppOpsManager::class.java)
            val mode = appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    /** app / data / cache bytes for [pkg], or null below API 26 or without access. */
    private fun sizeBreakdown(pkg: String): Map<String, Long>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        if (!hasUsageAccess()) return null
        return try {
            val stats = getSystemService(StorageStatsManager::class.java)
                .queryStatsForPackage(StorageManager.UUID_DEFAULT, pkg, Process.myUserHandle())
            mapOf(
                "app" to stats.appBytes,
                "data" to stats.dataBytes,
                "cache" to stats.cacheBytes,
                "total" to (stats.appBytes + stats.dataBytes + stats.cacheBytes),
            )
        } catch (_: Throwable) {
            // Package gone between the list render and the tap: the sheet just
            // keeps the APK size it already showed.
            null
        }
    }

    // -------------------------------------------------------------- shortcuts

    /**
     * Asks the launcher to pin [pkg]. True only means the request left the app:
     * the user still confirms in a system dialog and may cancel it.
     */
    private fun addShortcut(pkg: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        val label = try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0)
            ).toString()
        } catch (_: Throwable) {
            pkg
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            ShortcutManagerCompat.isRequestPinShortcutSupported(this)
        ) {
            val icon = appBitmap(pkg)?.let { IconCompat.createWithAdaptiveBitmap(it) }
                ?: IconCompat.createWithResource(this, R.mipmap.ic_launcher)
            val shortcut = ShortcutInfoCompat.Builder(this, "app_$pkg")
                // Launchers clip the short label around ten characters.
                .setShortLabel(label.take(10))
                .setLongLabel(label)
                .setIcon(icon)
                .setIntent(launchIntent.apply { action = Intent.ACTION_MAIN })
                .build()
            return ShortcutManagerCompat.requestPinShortcut(this, shortcut, null)
        }

        // Legacy launchers (API < 26) take a broadcast instead.
        return try {
            @Suppress("DEPRECATION")
            val shortcutIntent = Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
                putExtra(Intent.EXTRA_SHORTCUT_INTENT, launchIntent)
                putExtra(Intent.EXTRA_SHORTCUT_NAME, label)
                putExtra("duplicate", false)
                appBitmap(pkg)?.let { putExtra(Intent.EXTRA_SHORTCUT_ICON, it) }
            }
            sendBroadcast(shortcutIntent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** The icon as a bitmap, which is what a pinned shortcut wants (108dp). */
    private fun appBitmap(pkg: String): Bitmap? {
        return try {
            val drawable = packageManager.getApplicationIcon(pkg)
            if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: 108
                val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: 108
                Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { bmp ->
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    // --------------------------------------------------------------- actions

    private fun uninstall(pkg: String): Boolean {
        return try {
            startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun launch(pkg: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun openAppInfo(pkg: String): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun openPlayStore(pkg: String): Boolean {
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")))
            true
        } catch (_: Throwable) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")))
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    private fun startActivitySafely(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun freeMemory(): Map<String, Long> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return mapOf(
            "available" to info.availMem,
            "total" to info.totalMem,
            "lowMemory" to if (info.lowMemory) 1L else 0L
        )
    }

    // --------------------------------------------------------------- events

    private fun registerPackageReceiver() {
        if (receiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.data?.schemeSpecificPart?.let { iconCache.remove(it) }
                eventSink?.success(intent?.action)
            }
        }
        receiver = r
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(r, filter)
            }
        } catch (_: Throwable) {
            receiver = null
        }
    }

    private fun unregisterPackageReceiver() {
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Throwable) {
            }
        }
        receiver = null
    }
}

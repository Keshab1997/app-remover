package com.keshabstudios.goodbyeapps

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * The "Status bar notification" of docs/06: one ongoing, silent notification
 * that reports free RAM and free phone storage and opens the app on tap.
 *
 * Deliberately a plain notification and not a foreground service — no
 * FOREGROUND_SERVICE permission, no service-type justification for Play, and
 * it dies with the process, which the doc accepts.
 */
object NotificationHelper {

    private const val CHANNEL_ID = "status_bar"
    private const val NOTIFICATION_ID = 1001

    /** Flutter's shared_preferences plugin writes here, with a `flutter.` key prefix. */
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val PREF_KEY_ENABLED = "flutter.status_bar_enabled"

    /**
     * The Dart side owns this preference; reading it here is what lets the
     * free-memory refresh keep the tray up to date without a second channel
     * round trip. Note the prefix: without `flutter.` this always reads false.
     */
    fun isWanted(context: Context): Boolean =
        prefs(context).getBoolean(PREF_KEY_ENABLED, false)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Status bar",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows free RAM, free storage and quick access"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    fun show(context: Context, freeBytes: Long, totalBytes: Long) {
        ensureChannel(context)
        // Read disk space here, not at the call sites: the tray is refreshed
        // from four places (settings toggle, permission result, boot receiver,
        // list refresh) and none of them should be able to forget this half.
        val (storageFreeBytes, storageTotalBytes) = freeStorage()

        val openIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            // A notification icon must be white on transparent, never the logo.
            .setSmallIcon(R.drawable.ic_stat_memory)
            // Say RAM out loud: the app also lists app *sizes*, so bare
            // "memory" was read as storage. The expanded view spells out both.
            .setContentTitle("Free RAM ${format(freeBytes)}")
            .setContentText("Storage free ${format(storageFreeBytes)}")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Free RAM ${format(freeBytes)} of ${format(totalBytes)}\n" +
                        "Free storage ${format(storageFreeBytes)} of ${format(storageTotalBytes)}"
                )
            )
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied. The Dart caller shows the settings
            // dialog, so nothing else has to happen here.
        }
    }

    fun hide(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** Free / total bytes on the internal data partition. Needs no permission. */
    private fun freeStorage(): Pair<Long, Long> {
        return try {
            val stat = StatFs(Environment.getDataDirectory().path)
            Pair(
                stat.availableBlocksLong * stat.blockSizeLong,
                stat.blockCountLong * stat.blockSizeLong,
            )
        } catch (_: Throwable) {
            Pair(0L, 0L)
        }
    }

    private fun format(bytes: Long): String {
        val gb = bytes / 1024.0 / 1024.0 / 1024.0
        return if (gb >= 1) String.format("%.1f GB", gb)
        else String.format("%.0f MB", bytes / 1024.0 / 1024.0)
    }
}

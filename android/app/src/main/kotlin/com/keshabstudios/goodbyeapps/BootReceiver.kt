package com.keshabstudios.goodbyeapps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.os.Build

/**
 * Puts the tray notification back after a reboot (docs/06 §4), because a plain
 * notification dies with the process and there is no foreground service here.
 *
 * It never asks for a permission — there is no activity to host the dialog — so
 * a user who denied notifications simply gets nothing, which is the right
 * answer at boot.
 */
class BootReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!NotificationHelper.isWanted(context)) return

        val allowed =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        if (!allowed) return

        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        NotificationHelper.show(context, info.availMem, info.totalMem)
    }
}

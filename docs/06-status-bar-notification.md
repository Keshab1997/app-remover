# 06 — Status bar notification (free RAM + quick access)

**Priority:** nice-to-have (original app-এ ছিল)
**Effort:** ৩–৪ ঘণ্টা

---

## 1. Feature spec

Original app-এ Settings-এ দুইটা toggle আছে: **Status bar** আর **Status bar icon**।
আমরা একটাই toggle দেব, নাম **"Status bar notification"**।

Behaviour:

- Toggle ON → notification tray-তে একটা fixed (ongoing) notification
- Notification-এ দেখাবে: `Free memory 2.1 GB of 6.0 GB`
- Tap → app খোলে
- Action button: **Refresh** (value আপডেট করে), **Open** (app খোলে)
- Toggle OFF → notification যায়
- App kill হলে notification-ও চলে যায় (service ছাড়া); এটা acceptable, নিচে ব্যাখ্যা আছে

### Service লাগবে কি?

| Approach | Pros | Cons |
|---|---|---|
| **Plain notification (recommended)** | permission simple, Play policy easy | app বন্ধ হলে notification থাকবে না, live update নেই |
| Foreground service | live update, reboot-এও থাকে | `FOREGROUND_SERVICE` + `foregroundServiceType`, Play justification, battery complaint |

v1.1-এ **plain notification** করো। পরে দরকার হলে service-এ যাও।

---

## 2. Android side

### `android/app/build.gradle.kts`

```kotlin
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
```

### নতুন file: `NotificationHelper.kt`

Package: `com.keshabstudios.goodbyeapps`

```kotlin
package com.keshabstudios.goodbyeapps

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {

    private const val CHANNEL_ID = "status_bar"
    private const val NOTIFICATION_ID = 1001

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Status bar",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows free memory and quick access"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    fun show(context: Context, freeBytes: Long, totalBytes: Long) {
        ensureChannel(context)

        val openIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_memory)   // নিজের white vector বানাও
            .setContentTitle("Free memory")
            .setContentText("${format(freeBytes)} of ${format(totalBytes)}")
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied — caller decides what to show.
        }
    }

    fun hide(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun format(bytes: Long): String {
        val gb = bytes / 1024.0 / 1024.0 / 1024.0
        return if (gb >= 1) String.format("%.1f GB", gb)
        else String.format("%.0f MB", bytes / 1024.0 / 1024.0)
    }
}
```

`res/drawable/ic_stat_memory.xml` — 24dp white vector (notification icon অবশ্যই white,
transparent background):

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M17,7h-4V4h-2v3H7a2,2 0 0 0 -2,2v11a2,2 0 0 0 2,2h10a2,2 0 0 0 2,-2V9a2,2 0 0 0 -2,-2zM9,17H7v-2h2v2zM9,13H7v-2h2v2zM13,17h-2v-2h2v2zM13,13h-2v-2h2v2zM17,17h-2v-2h2v2zM17,13h-2v-2h2v2z" />
</vector>
```

### `MainActivity.kt`-এ method যোগ

`when (call.method)`-এ:

```kotlin
"setStatusBarNotification" -> {
    val enabled = call.argument<Boolean>("enabled") ?: false
    if (!enabled) {
        NotificationHelper.hide(this)
        result.success(true)
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
        PackageManager.PERMISSION_GRANTED
    ) {
        pendingNotificationResult = result
        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 401)
    } else {
        val memory = freeMemory()
        NotificationHelper.show(
            this,
            memory["available"] ?: 0L,
            memory["total"] ?: 0L,
        )
        result.success(true)
    }
}
```

Field + permission callback:

```kotlin
private var pendingNotificationResult: MethodChannel.Result? = null

override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode != 401) return
    val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
    pendingNotificationResult?.success(granted)
    pendingNotificationResult = null
    if (granted) {
        val memory = freeMemory()
        NotificationHelper.show(this, memory["available"] ?: 0L, memory["total"] ?: 0L)
    }
}
```

`freeMemory()` refresh করলেও notification-টা update করো (toggle ON থাকলে)। Preference
`SharedPreferences`-এ `status_bar_enabled` রাখো, যাতে `freeMemory` handler জানে।

---

## 3. Dart side

### `lib/services/native_apps.dart`

```dart
static Future<bool> setStatusBarNotification(bool enabled) async {
  final ok = await _channel.invokeMethod<bool>(
    'setStatusBarNotification',
    {'enabled': enabled},
  );
  return ok ?? false;
}
```

### `lib/services/settings.dart`

```dart
static const _statusBarKey = 'status_bar_enabled';
static final ValueNotifier<bool> statusBar = ValueNotifier(false);

// load()-এ যোগ করো
statusBar.value = prefs.getBool(_statusBarKey) ?? false;

static Future<void> setStatusBar(bool enabled) async {
  statusBar.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_statusBarKey, enabled);
}
```

### `lib/screens/settings_screen.dart`

`Appearance` section-এর পরে:

```dart
ValueListenableBuilder<bool>(
  valueListenable: AppSettings.statusBar,
  builder: (context, enabled, _) => SwitchListTile(
    secondary: const Icon(Icons.notifications_active_outlined),
    title: const Text('Status bar notification'),
    subtitle: const Text('Free memory and quick access in the tray'),
    value: enabled,
    onChanged: (value) async {
      final granted = await NativeApps.setStatusBarNotification(value);
      if (!granted) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Notifications are off'),
            content: const Text(
              'Allow notifications for this app in system settings, then try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  NativeApps.openUrl(
                    'android.settings.APP_NOTIFICATION_SETTINGS',
                  );
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        return;
      }
      await AppSettings.setStatusBar(value);
    },
  ),
),
```

`NativeApps.openUrl` শুধু `http`/`https` URI parse করে — app-specific settings intent-এর
জন্য আলাদা method বানাও:

```dart
// native
"notificationSettings" -> {
    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
    }
    result.success(startActivitySafely(intent))
}
```

---

## 4. Boot-এ ফিরিয়ে আনা (optional)

`AndroidManifest.xml`-এ receiver:

```xml
<receiver
    android:name=".BootReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

`BootReceiver` shared prefs দেখে notification আবার দেখাবে। service না থাকলে Android
কিছুক্ষণ পরে notification সরিয়ে দিতে পারে — এটা expected।

---

## 5. Acceptance criteria

- [ ] Toggle ON → tray-তে notification, RAM value সঠিক
- [ ] Toggle OFF → notification যায়
- [ ] Android 13-এ প্রথমবার ON করলে permission চায়
- [ ] Permission deny → dialog + settings shortcut, crash নেই
- [ ] Notification tap → app খোলে (নতুন instance না)
- [ ] Dark/light system UI-তে icon ঠিক দেখায়
- [ ] Notification icon monochrome (রঙিন লোগো নয়)
- [ ] App force-stop করলে notification যায় (plain notification-এর expected behaviour)
- [ ] Battery stats-এ excessive wakeup নেই

## 6. Files

```text
android/app/src/main/kotlin/.../NotificationHelper.kt   (নতুন)
android/app/src/main/kotlin/.../MainActivity.kt         (method + permission callback)
android/app/src/main/res/drawable/ic_stat_memory.xml    (নতুন)
android/app/build.gradle.kts                            (androidx.core dep)
lib/services/native_apps.dart
lib/services/settings.dart
lib/screens/settings_screen.dart
```

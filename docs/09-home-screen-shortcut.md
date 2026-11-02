# 09 — Home screen shortcut (pinned shortcut)

**Priority:** nice-to-have (original app-এ ছিল)
**Effort:** ১–২ ঘণ্টা

---

## 1. Feature

App list-এ যেকোনো app-এর action sheet-এ **"Add to home screen"** — tap করলে Android
system dialog দেখাবে, user confirm করলে home screen-এ ওই app-এর shortcut বসবে।

এটা uninstaller-এর জন্য useful: user প্রায়ই যে app-টা খোলে, সেটার shortcut বানিয়ে রাখে।

---

## 2. দুটো API

| API | Android | Behaviour |
|---|---|---|
| `ShortcutManagerCompat.requestPinShortcut` | 26+ | system confirmation dialog, safe, recommended |
| `INSTALL_SHORTCUT` broadcast | < 26 | পুরনো launcher-এ কাজ করে, permission লাগে |

আমরা দুইটাই handle করব, কিন্তু 26+ ফোনে শুধু প্রথমটা।

### Manifest (legacy fallback-এর জন্য)

```xml
<uses-permission android:name="com.android.launcher.permission.INSTALL_SHORTCUT" />
```

---

## 3. Kotlin

`androidx.core:core-ktx` দরকার (doc 06-এর সাথে same dependency, একবারই যোগ করবে):

```kotlin
implementation("androidx.core:core-ktx:1.13.1")
```

### Helper

```kotlin
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

private fun appBitmap(pkg: String): Bitmap? {
    return try {
        val drawable: Drawable = packageManager.getApplicationIcon(pkg)
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

private fun addShortcut(pkg: String): Boolean {
    val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
        ?: return false
    val label = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Throwable) {
        pkg
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        ShortcutManagerCompat.isRequestPinShortcutSupported(this)
    ) {
        val shortcut = ShortcutInfoCompat.Builder(this, "app_$pkg")
            .setShortLabel(label.take(10))          // launcher ~10 chars দেখায়
            .setLongLabel(label)
            .setIcon(appBitmap(pkg)?.let { IconCompat.createWithAdaptiveBitmap(it) }
                ?: IconCompat.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(launchIntent.apply { action = Intent.ACTION_MAIN })
            .build()
        return ShortcutManagerCompat.requestPinShortcut(this, shortcut, null)
    }

    // Legacy path (API < 26)
    return try {
        val shortcutIntent = Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
            putExtra(Intent.EXTRA_SHORTCUT_INTENT, launchIntent)
            putExtra(Intent.EXTRA_SHORTCUT_NAME, label)
            putExtra("duplicate", false)
            appBitmap(pkg)?.let {
                putExtra(Intent.EXTRA_SHORTCUT_ICON, it)
            }
        }
        sendBroadcast(shortcutIntent)
        true
    } catch (_: Throwable) {
        false
    }
}
```

Channel method:

```kotlin
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
```

> `requestPinShortcut` asynchronous — return `true` মানে "request পাঠানো হয়েছে",
> user cancel করলে false আসবে না। UI-তে "Home screen-এ যোগ করার request পাঠানো হয়েছে"
> ধরনের message দাও।

---

## 4. Dart

```dart
// native_apps.dart
static Future<bool> addShortcut(String packageName) async {
  final ok = await _channel.invokeMethod<bool>(
    'addShortcut',
    {'package': packageName},
  );
  return ok ?? false;
}
```

Action sheet-এ `Uninstall`-এর আগে:

```dart
ListTile(
  leading: const Icon(Icons.add_to_home_screen_outlined),
  title: const Text('Add to home screen'),
  onTap: () async {
    Navigator.pop(sheetContext);
    final ok = await NativeApps.addShortcut(app.packageName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Shortcut request sent'
            : 'This launcher does not support shortcuts'),
      ),
    );
  },
),
```

---

## 5. Edge cases

- launcher pin support করে না → message, crash না
- app-এর launch intent নেই (system service) → `false`, action disabled দেখানো ভালো
- একই app দুইবার add করলে launcher duplicate বানাতে পারে — `duplicate=false` legacy path-এ
- shortcut-এ icon 108dp-এর ছোট হলে launcher ছোট দেখায় — adaptive icon ব্যবহার করো
- Android 13 themed icon shortcut-এ apply হয় না (launcher-dependent)

---

## 6. Acceptance

- [ ] Android 8+ এ system pin dialog আসে
- [ ] Confirm করলে home screen-এ icon, tap-এ app খোলে
- [ ] Cancel করলে কিছু হয় না, crash না
- [ ] Launch intent নেই এমন app-এ action disabled
- [ ] Android 7 (API 24/25) emulator-এ legacy path কাজ করে
- [ ] Shortcut-এর label ellipsis ঠিক

## 7. Files

```text
android/app/src/main/AndroidManifest.xml     (INSTALL_SHORTCUT, legacy)
android/app/build.gradle.kts                 (androidx.core, doc 06-এর সাথে)
android/.../MainActivity.kt                  (addShortcut + bitmap helper)
lib/services/native_apps.dart
lib/screens/home_screen.dart
```

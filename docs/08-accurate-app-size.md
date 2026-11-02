# 08 — সঠিক app size (APK + data + cache)

**Priority:** accuracy — এখন শুধু APK file size দেখায়
**Effort:** ২ ঘণ্টা

---

## 1. সমস্যা

এখন `MainActivity.apkSize()` শুধু `sourceDir` + `splitSourceDirs`-এর file length যোগ করে।
তাই দেখা যায়:

- ৫০MB APK + ৩০০MB game data → list-এ **৫০MB** দেখায় (ভুল)
- cache ২০০MB → কিছুই দেখায় না

Original app সম্ভবত এভাবেই করত, কিন্তু user "কত জায়গা খালি হবে" জানে না।

---

## 2. সমাধান: `StorageStatsManager`

Android 8 (API 26)+ এ সঠিক breakdown পাওয়া যায়:

| Field | মানে |
|---|---|
| `appBytes` | APK + odex + libs |
| `dataBytes` | app-এর data (save, database) |
| `cacheBytes` | cache |

### Permission

`AndroidManifest.xml`:

```xml
<uses-permission
    android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions" />
```

এটা normal runtime permission নয় — **Settings → Special app access → Usage access**-এ
user-কে manually চালু করতে হয়। তাই:

- permission না থাকলে APK size-এ fallback
- settings-এ একটা row: "Detailed app sizes — Allow usage access"
- tap করলে `Settings.ACTION_USAGE_ACCESS_SETTINGS` খুলবে

---

## 3. Kotlin

```kotlin
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.os.Process
import android.os.storage.StorageManager

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

/** null = usage access নেই বা query fail */
private fun sizeBreakdown(pkg: String): Map<String, Long>? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
    if (!hasUsageAccess()) return null
    return try {
        val manager = getSystemService(StorageStatsManager::class.java)
        val stats = manager.queryStatsForPackage(
            StorageManager.UUID_DEFAULT,
            pkg,
            Process.myUserHandle(),
        )
        mapOf(
            "app" to stats.appBytes,
            "data" to stats.dataBytes,
            "cache" to stats.cacheBytes,
            "total" to (stats.appBytes + stats.dataBytes + stats.cacheBytes),
        )
    } catch (_: Throwable) {
        null
    }
}
```

Channel methods:

```kotlin
"hasUsageAccess" -> result.success(hasUsageAccess())

"usageAccessSettings" -> {
    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
    result.success(startActivitySafely(intent))
}

"getSizeBreakdown" -> {
    val pkg = call.argument<String>("package")
    if (pkg == null) {
        result.error("bad_args", "package is required", null)
    } else {
        executor.execute {
            val breakdown = sizeBreakdown(pkg)
            mainHandler.post { result.success(breakdown) }
        }
    }
}
```

### list-এ total দেখানো

`loadApps()`-এ প্রতিটা app-এর জন্য `sizeBreakdown` call করলে ২০০ app-এ ধীর হবে
(প্রতি query ~২–৫ms, মোট ১ সেকেন্ড)। দুটো পথ:

**Option A (recommended):** list-এ আগের মতো APK size; action sheet খুললে breakdown
lazy load করো। ব্যবহারকারী detail দেখতে চাইলে exact number পাবে।

**Option B:** `loadApps`-এ breakdown নাও, কিন্তু চালাও executor-এ; প্রথম frame আটকে
থাকবে না যদি metadata আগে পাঠাও আর breakdown পরে `EventChannel`-এ push করো।

v1.1-এ **Option A** করো — simple, দ্রুত, আর ৯০% user detail-ই দেখে না।

---

## 4. Dart

```dart
// native_apps.dart
static Future<bool> hasUsageAccess() async =>
    await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

static Future<bool> openUsageAccessSettings() async =>
    await _channel.invokeMethod<bool>('usageAccessSettings') ?? false;

static Future<({int app, int data, int cache, int total})?> sizeBreakdown(
  String packageName,
) async {
  final map = await _channel.invokeMapMethod<String, dynamic>(
    'getSizeBreakdown',
    {'package': packageName},
  );
  if (map == null) return null;
  return (
    app: (map['app'] as num?)?.toInt() ?? 0,
    data: (map['data'] as num?)?.toInt() ?? 0,
    cache: (map['cache'] as num?)?.toInt() ?? 0,
    total: (map['total'] as num?)?.toInt() ?? 0,
  );
}
```

Action sheet-এ (`lib/screens/home_screen.dart` → `_showActions`):

```dart
FutureBuilder(
  future: NativeApps.sizeBreakdown(app.packageName),
  builder: (context, snapshot) {
    final b = snapshot.data;
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _Row('App', formatBytes(b.app)),
          _Row('Data', formatBytes(b.data)),
          _Row('Cache', formatBytes(b.cache)),
        ],
      ),
    );
  },
),
```

Settings-এ:

```dart
ListTile(
  leading: const Icon(Icons.straighten),
  title: const Text('Detailed app sizes'),
  subtitle: const Text('Allow usage access for data and cache size'),
  onTap: () async {
    if (await NativeApps.hasUsageAccess()) return;
    await NativeApps.openUsageAccessSettings();
  },
),
```

---

## 5. Policy / listing

- `PACKAGE_USAGE_STATS` user-এর জন্য sensitive নয়, কিন্তু Play-এর **Data safety**-তে
  কিছু বদলায় না (কোনো data transmit হয় না)।
- Privacy policy-তে যোগ করো: "With your permission, the app reads per-app storage
  usage (app, data, cache) to show accurate sizes. It is shown only on your device."
- Description-এ "See app, data and cache size" লিখতে পারবে।

---

## 6. Acceptance

- [ ] Usage access granted → data/cache size দেখায়
- [ ] Usage access না থাকলে APK size-এ fallback, crash নেই
- [ ] Action sheet খুললে ৩০০ms-এর মধ্যে breakdown
- [ ] Uninstall করার পর size আর দেখায় না
- [ ] Android 8-এর নিচে feature hide (API 26 check)
- [ ] Settings-এর link straight to Usage access page

## 7. Files

```text
android/app/src/main/AndroidManifest.xml        (PACKAGE_USAGE_STATS)
android/.../MainActivity.kt                     (3 methods + helper)
lib/services/native_apps.dart
lib/screens/home_screen.dart                    (action sheet breakdown)
lib/screens/settings_screen.dart                (usage access row)
```

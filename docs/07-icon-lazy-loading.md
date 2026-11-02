# 07 — Icon lazy-loading (list fast করা)

**Priority:** performance — ২০০+ app থাকলে এখন ধীর লাগবে
**Effort:** ৩ ঘণ্টা

---

## 1. এখন কী হচ্ছে

`MainActivity.loadApps()` প্রতিটা app-এর icon PNG-তে convert করে (144×144), তারপর পুরো
list একসাথে channel দিয়ে Dart-এ পাঠায়।

খরচ:

| Step | Cost |
|---|---|
| `getInstalledApplications` | ৫০–১৫০ms |
| প্রতি icon draw + PNG compress | ৩–৮ms |
| ২০০ app-এর icon | ৬০০ms–১.৫s + ~১.৫MB transfer |
| Dart-এ PNG decode (প্রতি row) | UI thread-এ চাপ |

ফল: প্রথম launch-এ "Loading apps…" ২–৪ সেকেন্ড, scroll-এ jank।

---

## 2. Target design

দুই phase:

1. **`listApps`** — শুধু metadata (icon বাদ)। ১০০–২০০ms।
2. **`getIcon`** — প্রতি package-এর icon on demand, Kotlin-এ LRU cache।

List সাথে সাথে দেখা যাবে; iconগুলো row render হওয়ার সাথে সাথে আসবে।

```text
Flutter                          Kotlin
  │ listApps (no icons)             │
  │────────────────────────────────▶│  ~150ms
  │◀────────────────────────────────│  metadata list
  │  first frame render             │
  │ getIcon(pkg) × visible rows     │
  │────────────────────────────────▶│  cache hit: 0ms / miss: 3–8ms
  │◀────────────────────────────────│  PNG bytes
```

---

## 3. Kotlin changes

### `loadApps()` থেকে icon বাদ

```kotlin
out.add(mapOf(
    "packageName" to ai.packageName,
    "label" to pm.getApplicationLabel(ai).toString(),
    "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
    "sizeBytes" to apkSize(ai),
    "firstInstallTime" to (pkgInfo?.firstInstallTime ?: 0L),
    "lastUpdateTime" to (pkgInfo?.lastUpdateTime ?: 0L),
    "versionName" to (pkgInfo?.versionName ?: ""),
    "versionCode" to (if (pkgInfo != null) packageInfoVersionCode(pkgInfo) else 0L),
    // "icon" বাদ
))
```

### Icon cache + method

```kotlin
private val iconCache = object : LruCache<String, ByteArray>(120) {
    override fun sizeOf(key: String, value: ByteArray): Int = value.size
}

private fun loadIcon(pkg: String): ByteArray? {
    iconCache.get(pkg)?.let { return it }
    return try {
        val drawable = packageManager.getApplicationIcon(pkg)
        val bytes = drawableToPng(drawable, maxSize = 144) ?: return null
        iconCache.put(pkg, bytes)
        bytes
    } catch (_: Throwable) {
        null
    }
}
```

`when (call.method)`-এ:

```kotlin
"getIcon" -> {
    val pkg = call.argument<String>("package")
    if (pkg == null) {
        result.error("bad_args", "package is required", null)
    } else {
        executor.execute {
            val bytes = loadIcon(pkg)
            mainHandler.post { result.success(bytes) }
        }
    }
}
```

> `getPackageInfo`/`getApplicationIcon` main thread-এ করো না — executor-এ রাখো।

### Batch (optional)

প্রথম screen-এ ৮–১০টা icon একসাথে লাগে। একটা round-trip বাঁচাতে:

```kotlin
"getIcons" -> {
    val packages = call.argument<List<String>>("packages") ?: emptyList()
    executor.execute {
        val map = packages.associateWith { loadIcon(it) }
        mainHandler.post { result.success(map) }
    }
}
```

---

## 4. Dart changes

### `lib/models/app_info.dart`

`icon` field আর `fromMap`-এর icon parse বাদ দাও (অথবা রাখো, null হবে)।

### `lib/services/native_apps.dart`

```dart
static Future<Uint8List?> getIcon(String packageName) async {
  return _channel.invokeMethod<Uint8List>('getIcon', {'package': packageName});
}
```

### নতুন `lib/services/icon_store.dart`

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'native_apps.dart';

class IconStore extends ChangeNotifier {
  IconStore._();
  static final IconStore instance = IconStore._();

  final Map<String, Uint8List?> _cache = {};
  final Set<String> _inFlight = {};

  Uint8List? get(String pkg) => _cache[pkg];

  void request(String pkg) {
    if (_cache.containsKey(pkg) || _inFlight.contains(pkg)) return;
    _inFlight.add(pkg);
    NativeApps.getIcon(pkg).then((bytes) {
      _cache[pkg] = bytes;
      _inFlight.remove(pkg);
      notifyListeners();
    }).catchError((Object _) {
      _cache[pkg] = null;
      _inFlight.remove(pkg);
      notifyListeners();
    });
  }
}
```

> `notifyListeners()` প্রতি icon-এ করলে ২০০ বার rebuild হবে। ভালো: ৫০ms debounce, বা
> `ValueNotifier<Uint8List?>` per package। প্রথম version-এ simple রাখো, পরে tune করো।

### `lib/widgets/app_tile.dart`

```dart
class AppTile extends StatefulWidget { ... }

class _AppTileState extends State<AppTile> {
  @override
  void initState() {
    super.initState();
    IconStore.instance.request(widget.app.packageName);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: IconStore.instance,
      builder: (context, _) {
        final icon = IconStore.instance.get(widget.app.packageName);
        return AppIcon(icon: icon, scheme: Theme.of(context).colorScheme);
      },
    );
  }
}
```

`ListView.builder`-এ শুধু visible row-ই `initState` চালাবে — তাই লিস্ট দ্রুত।

---

## 5. Cache eviction

`IconStore._cache` সীমাহীন হলে ৫০০ app-এ ~৪MB RAM। ঠিক আছে, কিন্তু চাইলে:

```dart
static const _maxEntries = 200;
// insert করার আগে: if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first);
```

(Kotlin side-এ `LruCache` ইতিমধ্যে 120 entry / 8MB-এ সীমিত।)

---

## 6. Acceptance

- [ ] List প্রথম frame < ৫০০ms (cold start, ২০০ app)
- [ ] Scroll-এ jank নেই (`flutter run --profile` + DevTools)
- [ ] Icon না আসা পর্যন্ত fallback icon (খালি জায়গা নয়)
- [ ] একই app-এ ফিরে এলে icon সাথে সাথে (cache hit)
- [ ] ৫০০ app-এ RAM < ৫০MB
- [ ] Icon quality আগের মতোই

## 7. Files

```text
android/.../MainActivity.kt        (loadApps থেকে icon বাদ, getIcon + LruCache)
lib/models/app_info.dart           (icon optional)
lib/services/native_apps.dart      (getIcon)
lib/services/icon_store.dart       (নতুন)
lib/widgets/app_tile.dart          (StatefulWidget + IconStore)
```

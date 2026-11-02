import 'package:flutter/services.dart';

import '../models/app_info.dart';

/// Thin wrapper around the Kotlin MethodChannel / EventChannel bridge.
class NativeApps {
  NativeApps._();

  static const MethodChannel _channel = MethodChannel('goodbye_apps/native');
  static const EventChannel _events = EventChannel('goodbye_apps/events');

  static Future<List<AppInfo>> listApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('listApps');
    final apps = (result ?? const [])
        .map(AppInfo.fromMap)
        .where((app) => app.packageName.isNotEmpty)
        .toList();
    return apps;
  }

  /// Icon of one package, PNG bytes at 144px, or null when it has none.
  ///
  /// Fetched per row instead of inside `listApps`: decoding 200 icons up
  /// front is what made the first frame take seconds (docs/07).
  static Future<Uint8List?> getIcon(String packageName) async {
    final bytes = await _channel.invokeMethod<Uint8List>('getIcon', {
      'package': packageName,
    });
    return (bytes == null || bytes.isEmpty) ? null : bytes;
  }

  static Future<bool> uninstall(String packageName) async {
    final ok = await _channel.invokeMethod<bool>('uninstall', {
      'package': packageName,
    });
    return ok ?? false;
  }

  static Future<bool> launch(String packageName) async {
    final ok = await _channel.invokeMethod<bool>('launch', {
      'package': packageName,
    });
    return ok ?? false;
  }

  static Future<bool> openAppInfo(String packageName) async {
    final ok = await _channel.invokeMethod<bool>('appInfo', {
      'package': packageName,
    });
    return ok ?? false;
  }

  static Future<bool> openPlayStore(String packageName) async {
    final ok = await _channel.invokeMethod<bool>('playStore', {
      'package': packageName,
    });
    return ok ?? false;
  }

  static Future<bool> openUrl(String url) async {
    final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
    return ok ?? false;
  }

  static Future<bool> share(String text) async {
    final ok = await _channel.invokeMethod<bool>('shareApp', {'text': text});
    return ok ?? false;
  }

  /// Whether the user granted usage access (Settings → Special app access →
  /// Usage access). Not a runtime permission, so it can only ever be false
  /// until the user turns it on by hand.
  static Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  /// Opens the usage-access page, so the user can grant what the app cannot ask
  /// for itself. False when the device has no such screen.
  static Future<bool> openUsageAccessSettings() async =>
      await _channel.invokeMethod<bool>('usageAccessSettings') ?? false;

  /// Exact app / data / cache bytes for [packageName] (docs/08), or null when
  /// usage access is not granted — the caller then keeps the APK size.
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

  /// Returns (available, total) bytes of RAM.
  static Future<({int available, int total})> freeMemory() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('freeMemory');
    return (
      available: (map?['available'] as num?)?.toInt() ?? 0,
      total: (map?['total'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<({String name, int code})> appVersion() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('appVersion');
    return (
      name: map?['versionName'] as String? ?? '',
      code: (map?['versionCode'] as num?)?.toInt() ?? 0,
    );
  }

  /// Emits whenever an app is installed, removed or updated on the device.
  static Stream<String> packageChanges() {
    return _events.receiveBroadcastStream().map((event) => event.toString());
  }
}

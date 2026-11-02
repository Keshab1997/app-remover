import 'package:flutter/services.dart';

import '../models/app_info.dart';

/// Thin wrapper around the Kotlin MethodChannel / EventChannel bridge.
class NativeApps {
  NativeApps._();

  static const MethodChannel _channel = MethodChannel('app_remover/native');
  static const EventChannel _events = EventChannel('app_remover/events');

  static Future<List<AppInfo>> listApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('listApps');
    final apps = (result ?? const [])
        .map(AppInfo.fromMap)
        .where((app) => app.packageName.isNotEmpty)
        .toList();
    return apps;
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

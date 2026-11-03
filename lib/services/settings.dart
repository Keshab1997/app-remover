import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences persisted with shared_preferences.
class AppSettings {
  AppSettings._();

  static const _themeKey = 'theme_mode';

  /// Read by the Kotlin side as `flutter.status_bar_enabled` to decide whether
  /// a memory refresh should also repaint the tray notification (docs/06).
  static const _statusBarKey = 'status_bar_enabled';
  static const _sizesHintKey = 'sizes_hint_on';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  static final ValueNotifier<bool> statusBar = ValueNotifier(false);

  /// Whether the sheet may still explain how to get exact sizes. Default on:
  /// without it the feature is invisible to anyone who has not granted usage
  /// access (docs/12 P0-2).
  static final ValueNotifier<bool> sizesHint = ValueNotifier(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    themeMode.value = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    statusBar.value = prefs.getBool(_statusBarKey) ?? false;
    sizesHint.value = prefs.getBool(_sizesHintKey) ?? true;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  static Future<void> setSizesHint(bool show) async {
    sizesHint.value = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sizesHintKey, show);
  }

  /// Persists the toggle only. Whether the notification is actually up is the
  /// native call's answer, because the user can deny POST_NOTIFICATIONS.
  static Future<void> setStatusBar(bool enabled) async {
    statusBar.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusBarKey, enabled);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys below are what `NotificationHelper.kt` reads back with a `flutter.`
/// prefix, so a rename here silently breaks the tray notification.
void main() {
  setUp(() {
    AppSettings.themeMode.value = ThemeMode.system;
    AppSettings.statusBar.value = false;
  });

  test('defaults are system theme and no notification', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();

    expect(AppSettings.themeMode.value, ThemeMode.system);
    expect(AppSettings.statusBar.value, isFalse);
  });

  test('an unknown stored theme is treated as system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'neon'});
    await AppSettings.load();

    expect(AppSettings.themeMode.value, ThemeMode.system);
  });

  test('the status bar toggle survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.setStatusBar(true);
    AppSettings.statusBar.value = false; // as if the process died

    await AppSettings.load();
    expect(AppSettings.statusBar.value, isTrue);

    await AppSettings.setStatusBar(false);
    expect(
      (await SharedPreferences.getInstance()).getBool('status_bar_enabled'),
      isFalse,
    );
  });

  test('the theme is written back in the words the loader reads', () async {
    SharedPreferences.setMockInitialValues({});

    await AppSettings.setThemeMode(ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');

    await AppSettings.load();
    expect(AppSettings.themeMode.value, ThemeMode.dark);
  });
}

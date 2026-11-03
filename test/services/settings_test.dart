import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/models/app_info.dart';
import 'package:goodbye_apps/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys below are what `NotificationHelper.kt` reads back with a `flutter.`
/// prefix, so a rename here silently breaks the tray notification.
void main() {
  setUp(() {
    AppSettings.themeMode.value = ThemeMode.system;
    AppSettings.statusBar.value = false;
    AppSettings.sortField.value = SortField.size;
    AppSettings.sortAscending.value = false;
    AppSettings.systemTab.value = false;
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
  test('sort order and last tab outlive a restart', () async {
    SharedPreferences.setMockInitialValues({});

    await AppSettings.setSort(SortField.name, true);
    await AppSettings.setSystemTab(true);
    AppSettings.sortField.value = SortField.size;
    AppSettings.sortAscending.value = false;
    AppSettings.systemTab.value = false;
    await AppSettings.load();

    expect(AppSettings.sortField.value, SortField.name);
    expect(AppSettings.sortAscending.value, isTrue);
    expect(AppSettings.systemTab.value, isTrue);
  });

  test('a first run sorts by size, biggest first', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();

    expect(AppSettings.sortField.value, SortField.size);
    expect(AppSettings.sortAscending.value, isFalse);
    expect(AppSettings.systemTab.value, isFalse);
  });
  test(
    'the last five searches are kept, newest first, without repeats',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.load();

      for (final query in ['map', 'games', 'map', ' a ', 'b', 'c', 'd']) {
        await AppSettings.rememberSearch(query);
      }

      expect(AppSettings.searchHistory.value, ['d', 'c', 'b', 'a', 'map']);

      AppSettings.searchHistory.value = const [];
      await AppSettings.load();
      expect(AppSettings.searchHistory.value, ['d', 'c', 'b', 'a', 'map']);

      await AppSettings.clearSearchHistory();
      expect(AppSettings.searchHistory.value, isEmpty);
    },
  );

  test('the offline note is shown once', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
    expect(AppSettings.offlineNoteSeen.value, isFalse);

    await AppSettings.setOfflineNoteSeen();
    AppSettings.offlineNoteSeen.value = false;
    await AppSettings.load();

    expect(AppSettings.offlineNoteSeen.value, isTrue);
  });
}

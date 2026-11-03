import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_info.dart';

/// User preferences persisted with shared_preferences.
class AppSettings {
  AppSettings._();

  static const _themeKey = 'theme_mode';

  /// Read by the Kotlin side as `flutter.status_bar_enabled` to decide whether
  /// a memory refresh should also repaint the tray notification (docs/06).
  static const _statusBarKey = 'status_bar_enabled';
  static const _sizesHintKey = 'sizes_hint_on';
  static const _sortFieldKey = 'sort_field';
  static const _sortAscendingKey = 'sort_ascending';
  static const _systemTabKey = 'system_tab';
  static const _searchHistoryKey = 'search_history';
  static const _offlineNoteSeenKey = 'offline_note_seen';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  static final ValueNotifier<bool> statusBar = ValueNotifier(false);

  /// Whether the sheet may still explain how to get exact sizes. Default on:
  /// without it the feature is invisible to anyone who has not granted usage
  /// access (docs/12 P0-2).
  static final ValueNotifier<bool> sizesHint = ValueNotifier(true);

  /// Sort order and last tab. Opening the app on the same view it was left on
  /// is the whole point: a 200-app list sorted by size descending once should
  /// not have to be sorted again on every launch (docs/12 P1-6). The defaults
  /// are that same view, because size is the one thing this app can act on.
  static final ValueNotifier<SortField> sortField = ValueNotifier(
    SortField.size,
  );
  static final ValueNotifier<bool> sortAscending = ValueNotifier(false);
  static final ValueNotifier<bool> systemTab = ValueNotifier(false);

  /// The last few things typed into search, newest first. Searching for the
  /// same app again is the common case, and the keyboard does not remember it
  /// for you (docs/12 P2-14).
  static final ValueNotifier<List<String>> searchHistory = ValueNotifier(
    const [],
  );
  static const historyLimit = 5;

  /// Whether the one-time "works offline" line has been dismissed.
  static final ValueNotifier<bool> offlineNoteSeen = ValueNotifier(false);

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
    sortField.value = switch (prefs.getString(_sortFieldKey)) {
      'name' => SortField.name,
      'date' => SortField.date,
      _ => SortField.size,
    };
    sortAscending.value = prefs.getBool(_sortAscendingKey) ?? false;
    systemTab.value = prefs.getBool(_systemTabKey) ?? false;
    searchHistory.value = List.unmodifiable(
      prefs.getStringList(_searchHistoryKey) ?? const [],
    );
    offlineNoteSeen.value = prefs.getBool(_offlineNoteSeenKey) ?? false;
  }

  static Future<void> rememberSearch(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    final previous = searchHistory.value;
    final next = List<String>.from(
      <String>[
        text,
        ...searchHistory.value.where((q) => q != text),
      ].take(historyLimit),
    );
    if (_sameList(previous, next)) return;
    searchHistory.value = next;
    await _persist((prefs) => prefs.setStringList(_searchHistoryKey, next));
  }

  /// Value equality for a list of strings: the notifier would otherwise fire on
  /// every repeated search and repaint the whole suggestion row.
  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> clearSearchHistory() async {
    if (searchHistory.value.isEmpty) return;
    searchHistory.value = const [];
    await _persist((prefs) => prefs.remove(_searchHistoryKey));
  }

  static Future<void> setOfflineNoteSeen() async {
    if (offlineNoteSeen.value) return;
    offlineNoteSeen.value = true;
    await _persist((prefs) => prefs.setBool(_offlineNoteSeenKey, true));
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

  static Future<void> setSort(SortField field, bool ascending) async {
    sortField.value = field;
    sortAscending.value = ascending;
    await _persist((prefs) async {
      await prefs.setString(_sortFieldKey, field.name);
      await prefs.setBool(_sortAscendingKey, ascending);
    });
  }

  static Future<void> setSystemTab(bool system) async {
    systemTab.value = system;
    await _persist((prefs) => prefs.setBool(_systemTabKey, system));
  }

  /// Writes through to the store when there is one. The in-memory notifier has
  /// already been updated by the caller, so a build with no store behind it -
  /// a widget test, a platform the plugin does not serve - loses a preference
  /// and nothing else.
  static Future<void> _persist(
    Future<void> Function(SharedPreferences prefs) write,
  ) async {
    try {
      await write(await SharedPreferences.getInstance());
    } on MissingPluginException {
      // Nothing to persist to.
    }
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

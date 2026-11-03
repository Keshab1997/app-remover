// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Goodbye Apps';

  @override
  String tabUserApps(int count) {
    return 'User apps ($count)';
  }

  @override
  String tabSystemApps(int count) {
    return 'System apps ($count)';
  }

  @override
  String get loadingApps => 'Loading apps…';

  @override
  String get searchApps => 'Search apps';

  @override
  String get appsNotFound => 'Apps not found';

  @override
  String get noMatches => 'No matches';

  @override
  String get pullToRefresh => 'Pull down to refresh the list.';

  @override
  String get tryDifferentSearch => 'Try a different name or package.';

  @override
  String get loadFailed => 'Could not read the installed app list.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get sort => 'Sort';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortBySize => 'Sort by size';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get toggleSortDirection => 'Toggle sort direction';

  @override
  String get search => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get cancel => 'Cancel';

  @override
  String get settings => 'Settings';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshMemory => 'Refresh memory';

  @override
  String get selectAll => 'Select all';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String appsAndSize(int count, String size) {
    return '$count apps • $size';
  }

  @override
  String get freeMemory => 'Free memory';

  @override
  String usedOfTotal(String used, String total) {
    return '$used / $total used';
  }

  @override
  String get uninstall => 'Uninstall';

  @override
  String get uninstallOne => 'Uninstall app?';

  @override
  String uninstallMany(int count) {
    return 'Uninstall $count apps?';
  }

  @override
  String get uninstallConfirmBody =>
      'The system will ask you to confirm each uninstall.';

  @override
  String get open => 'Open';

  @override
  String get appInfo => 'App info';

  @override
  String get searchInPlay => 'Search in Google Play';

  @override
  String get addToHomeScreen => 'Add to home screen';

  @override
  String get shortcutRequested => 'Confirm the shortcut on the home screen';

  @override
  String get shortcutUnsupported => 'This app or launcher can\'t be pinned';

  @override
  String get systemAppsProtected => 'System apps can\'t be uninstalled';

  @override
  String versionAndSize(String version, String size) {
    return 'v$version • $size';
  }

  @override
  String get sizeApp => 'App';

  @override
  String get sizeData => 'Data';

  @override
  String get sizeCache => 'Cache';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionStatusBar => 'Status bar';

  @override
  String get sectionStorage => 'Storage';

  @override
  String get sectionAbout => 'About';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get statusBarToggle => 'Status bar notification';

  @override
  String get statusBarOn => 'Free memory in the tray, refreshed with the list';

  @override
  String get statusBarOff => 'Show free memory in the tray';

  @override
  String get notificationsOffTitle => 'Notifications are off';

  @override
  String get notificationsOffBody =>
      'Allow notifications for Goodbye Apps in system settings, then turn this back on.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get detailedAppSizes => 'Detailed app sizes';

  @override
  String get usageAccessOn =>
      'Usage access is on — sheets show app, data and cache';

  @override
  String get usageAccessOff =>
      'Turn on usage access to see data and cache size';

  @override
  String get rateApp => 'Rate this app';

  @override
  String get rateSubtitle => 'Give us 5 stars on Google Play';

  @override
  String get shareApp => 'Share app';

  @override
  String shareBody(String link) {
    return 'Check out Goodbye Apps – a simple way to uninstall apps.\n$link';
  }

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get version => 'Version';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sizesHintTitle => 'Exact sizes need usage access';

  @override
  String get enable => 'Enable';

  @override
  String get noThanks => 'No thanks';

  @override
  String uninstallingProgress(int done, int total) {
    return 'Removing $done of $total';
  }

  @override
  String get uninstallNothingRemoved => 'No apps were removed';

  @override
  String get tabUserAppsLabel => 'User apps';

  @override
  String get tabSystemAppsLabel => 'System apps';

  @override
  String selectAllInTab(Object count, Object tab) {
    return 'Select all $count in $tab';
  }

  @override
  String get filterUnused => 'Not used in 90 days';

  @override
  String get filterLarge => 'Over 500 MB';

  @override
  String get filterRecent => 'Installed recently';

  @override
  String notOpenedSince(Object date) {
    return 'Not opened since $date';
  }

  @override
  String get filtersMatchNothing => 'Nothing matches these filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String appsShownOf(int shown, int total) {
    return 'Showing $shown of $total apps';
  }

  @override
  String uninstallSummaryOne(String size) {
    return 'Freed $size from one app';
  }

  @override
  String uninstallSummaryMany(String size, int count) {
    return 'Freed $size from $count apps';
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// Brand name — never translated.
  ///
  /// In en, this message translates to:
  /// **'Goodbye Apps'**
  String get appTitle;

  /// No description provided for @tabUserApps.
  ///
  /// In en, this message translates to:
  /// **'User apps ({count})'**
  String tabUserApps(int count);

  /// No description provided for @tabSystemApps.
  ///
  /// In en, this message translates to:
  /// **'System apps ({count})'**
  String tabSystemApps(int count);

  /// No description provided for @loadingApps.
  ///
  /// In en, this message translates to:
  /// **'Loading apps…'**
  String get loadingApps;

  /// Search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @appsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Apps not found'**
  String get appsNotFound;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh the list.'**
  String get pullToRefresh;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or package.'**
  String get tryDifferentSearch;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the installed app list.'**
  String get loadFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get sortByName;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get sortByDate;

  /// No description provided for @sortBySize.
  ///
  /// In en, this message translates to:
  /// **'Sort by size'**
  String get sortBySize;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @toggleSortDirection.
  ///
  /// In en, this message translates to:
  /// **'Toggle sort direction'**
  String get toggleSortDirection;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshMemory.
  ///
  /// In en, this message translates to:
  /// **'Refresh memory'**
  String get refreshMemory;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @appsAndSize.
  ///
  /// In en, this message translates to:
  /// **'{count} apps • {size}'**
  String appsAndSize(int count, String size);

  /// No description provided for @freeMemory.
  ///
  /// In en, this message translates to:
  /// **'Free memory'**
  String get freeMemory;

  /// No description provided for @usedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} / {total} used'**
  String usedOfTotal(String used, String total);

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @uninstallOne.
  ///
  /// In en, this message translates to:
  /// **'Uninstall app?'**
  String get uninstallOne;

  /// No description provided for @uninstallMany.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {count} apps?'**
  String uninstallMany(int count);

  /// No description provided for @uninstallConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The system will ask you to confirm each uninstall.'**
  String get uninstallConfirmBody;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @appInfo.
  ///
  /// In en, this message translates to:
  /// **'App info'**
  String get appInfo;

  /// No description provided for @searchInPlay.
  ///
  /// In en, this message translates to:
  /// **'Search in Google Play'**
  String get searchInPlay;

  /// No description provided for @addToHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Add to home screen'**
  String get addToHomeScreen;

  /// No description provided for @shortcutRequested.
  ///
  /// In en, this message translates to:
  /// **'Confirm the shortcut on the home screen'**
  String get shortcutRequested;

  /// No description provided for @shortcutUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This app or launcher can\'t be pinned'**
  String get shortcutUnsupported;

  /// No description provided for @systemAppsProtected.
  ///
  /// In en, this message translates to:
  /// **'System apps can\'t be uninstalled'**
  String get systemAppsProtected;

  /// No description provided for @versionAndSize.
  ///
  /// In en, this message translates to:
  /// **'v{version} • {size}'**
  String versionAndSize(String version, String size);

  /// Column label of the storage breakdown.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sizeApp;

  /// No description provided for @sizeData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sizeData;

  /// No description provided for @sizeCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get sizeCache;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionStatusBar.
  ///
  /// In en, this message translates to:
  /// **'Status bar'**
  String get sectionStatusBar;

  /// No description provided for @sectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get sectionStorage;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @statusBarToggle.
  ///
  /// In en, this message translates to:
  /// **'Status bar notification'**
  String get statusBarToggle;

  /// No description provided for @statusBarOn.
  ///
  /// In en, this message translates to:
  /// **'Free memory in the tray, refreshed with the list'**
  String get statusBarOn;

  /// No description provided for @statusBarOff.
  ///
  /// In en, this message translates to:
  /// **'Show free memory in the tray'**
  String get statusBarOff;

  /// No description provided for @notificationsOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsOffTitle;

  /// No description provided for @notificationsOffBody.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for Goodbye Apps in system settings, then turn this back on.'**
  String get notificationsOffBody;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @detailedAppSizes.
  ///
  /// In en, this message translates to:
  /// **'Detailed app sizes'**
  String get detailedAppSizes;

  /// No description provided for @usageAccessOn.
  ///
  /// In en, this message translates to:
  /// **'Usage access is on — sheets show app, data and cache'**
  String get usageAccessOn;

  /// No description provided for @usageAccessOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on usage access to see data and cache size'**
  String get usageAccessOff;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate this app'**
  String get rateApp;

  /// No description provided for @rateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give us 5 stars on Google Play'**
  String get rateSubtitle;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareApp;

  /// No description provided for @shareBody.
  ///
  /// In en, this message translates to:
  /// **'Check out Goodbye Apps – a simple way to uninstall apps.\n{link}'**
  String shareBody(String link);

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @sizesHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact sizes need usage access'**
  String get sizesHintTitle;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @noThanks.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get noThanks;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

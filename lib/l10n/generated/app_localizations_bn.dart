// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Goodbye Apps';

  @override
  String tabUserApps(int count) {
    return 'ইউজার অ্যাপ ($count)';
  }

  @override
  String tabSystemApps(int count) {
    return 'সিস্টেম অ্যাপ ($count)';
  }

  @override
  String get loadingApps => 'অ্যাপ লোড হচ্ছে…';

  @override
  String get searchApps => 'অ্যাপ খুঁজুন';

  @override
  String get appsNotFound => 'কোনো অ্যাপ পাওয়া যায়নি';

  @override
  String get noMatches => 'কিছু পাওয়া যায়নি';

  @override
  String get pullToRefresh => 'লিস্ট রিফ্রেশ করতে নিচে টানুন।';

  @override
  String get tryDifferentSearch => 'অন্য নাম বা প্যাকেজ দিয়ে চেষ্টা করুন।';

  @override
  String get loadFailed => 'ইনস্টল করা অ্যাপের লিস্ট পড়া যায়নি।';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get sort => 'সাজান';

  @override
  String get sortByName => 'নাম অনুযায়ী সাজান';

  @override
  String get sortByDate => 'তারিখ অনুযায়ী সাজান';

  @override
  String get sortBySize => 'সাইজ অনুযায়ী সাজান';

  @override
  String get ascending => 'ছোট থেকে বড়';

  @override
  String get descending => 'বড় থেকে ছোট';

  @override
  String get toggleSortDirection => 'সাজানোর দিক বদলান';

  @override
  String get search => 'খুঁজুন';

  @override
  String get clear => 'মুছুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get settings => 'সেটিংস';

  @override
  String get refresh => 'রিফ্রেশ';

  @override
  String get refreshMemory => 'RAM ও স্টোরেজ রিফ্রেশ করুন';

  @override
  String get selectAll => 'সব নির্বাচন করুন';

  @override
  String get cancelSelection => 'নির্বাচন বাতিল';

  @override
  String selectedCount(int count) {
    return '$countটি নির্বাচিত';
  }

  @override
  String appsAndSize(int count, String size) {
    return '$countটি অ্যাপ • $size';
  }

  @override
  String get freeMemory => 'ফ্রি RAM';

  @override
  String usedOfTotal(String used, String total) {
    return '$used / $total ব্যবহৃত';
  }

  @override
  String get uninstall => 'আনইনস্টল';

  @override
  String get tapAgainToUninstall => 'নিশ্চিত করতে আবার চাপুন';

  @override
  String uninstallMany(int count) {
    return '$countটি অ্যাপ আনইনস্টল করবেন?';
  }

  @override
  String get uninstallConfirmBody =>
      'প্রতিটি আনইনস্টলের জন্য সিস্টেম আবার জিজ্ঞাসা করবে।';

  @override
  String get open => 'খুলুন';

  @override
  String get appInfo => 'অ্যাপের তথ্য';

  @override
  String get searchInPlay => 'Google Play-তে খুঁজুন';

  @override
  String get addToHomeScreen => 'হোম স্ক্রিনে যোগ করুন';

  @override
  String get shortcutRequested => 'হোম স্ক্রিনে shortcut নিশ্চিত করুন';

  @override
  String get shortcutUnsupported => 'এই অ্যাপ বা launcher pin করা যায় না';

  @override
  String get systemAppsProtected => 'সিস্টেম অ্যাপ আনইনস্টল করা যায় না';

  @override
  String versionAndSize(String version, String size) {
    return 'v$version • $size';
  }

  @override
  String get sizeApp => 'অ্যাপ';

  @override
  String get sizeData => 'ডেটা';

  @override
  String get sizeCache => 'ক্যাশে';

  @override
  String get sectionAppearance => 'অ্যাপিয়ারেন্স';

  @override
  String get sectionStatusBar => 'স্ট্যাটাস বার';

  @override
  String get sectionStorage => 'স্টোরেজ';

  @override
  String get sectionAbout => 'সম্পর্কে';

  @override
  String get theme => 'থিম';

  @override
  String get systemDefault => 'সিস্টেম ডিফল্ট';

  @override
  String get light => 'লাইট';

  @override
  String get dark => 'ডার্ক';

  @override
  String get statusBarToggle => 'স্ট্যাটাস বার নোটিফিকেশন';

  @override
  String get statusBarOn =>
      'ট্রে-তে ফ্রি RAM ও স্টোরেজ, লিস্ট রিফ্রেশের সাথে আপডেট হয়';

  @override
  String get statusBarOff => 'ট্রে-তে ফ্রি RAM ও স্টোরেজ দেখান';

  @override
  String get notificationsOffTitle => 'নোটিফিকেশন বন্ধ আছে';

  @override
  String get notificationsOffBody =>
      'সিস্টেম সেটিংসে Goodbye Apps-এর নোটিফিকেশন চালু করে, তারপর এটা আবার অন করুন।';

  @override
  String get openSettings => 'সেটিংস খুলুন';

  @override
  String get detailedAppSizes => 'বিস্তারিত অ্যাপ সাইজ';

  @override
  String get usageAccessOn =>
      'Usage access চালু আছে — শিটে অ্যাপ, ডেটা ও ক্যাশে দেখায়';

  @override
  String get usageAccessOff =>
      'ডেটা ও ক্যাশে সাইজ দেখতে usage access চালু করুন';

  @override
  String get rateApp => 'অ্যাপটি রেট করুন';

  @override
  String get rateSubtitle => 'Google Play-তে ৫ স্টার দিন';

  @override
  String get shareApp => 'অ্যাপ শেয়ার করুন';

  @override
  String shareBody(String link) {
    return 'Goodbye Apps দেখুন — দুই ট্যাপে অ্যাপ আনইনস্টল করুন।\n$link';
  }

  @override
  String get sendFeedback => 'মতামত পাঠান';

  @override
  String get privacyPolicy => 'প্রাইভেসি পলিসি';

  @override
  String get version => 'ভার্সন';

  @override
  String get clearSearch => 'সার্চ মুছুন';

  @override
  String get sizesHintTitle => 'সঠিক সাইজের জন্য usage access লাগে';

  @override
  String get enable => 'চালু করুন';

  @override
  String get noThanks => 'লাগবে না';

  @override
  String uninstallingProgress(int done, int total) {
    return '$totalটির মধ্যে $doneটি সরানো হচ্ছে';
  }

  @override
  String get uninstallNothingRemoved => 'কোনো অ্যাপ সরানো হয়নি';

  @override
  String get tabUserAppsLabel => 'ইউজার অ্যাপ';

  @override
  String get tabSystemAppsLabel => 'সিস্টেম অ্যাপ';

  @override
  String selectAllInTab(Object count, Object tab) {
    return '$tab-এ $countটি বেছে নিন';
  }

  @override
  String get filterUnused => '৯০ দিন ব্যবহার হয়নি';

  @override
  String get filterLarge => '৫০০ MB-এর বেশি';

  @override
  String get filterRecent => 'সম্প্রতি ইনস্টল';

  @override
  String notOpenedSince(Object date) {
    return '$date-এর পর খোলা হয়নি';
  }

  @override
  String get filtersMatchNothing => 'এই ফিল্টারে কিছু মেলেনি';

  @override
  String get clearFilters => 'ফিল্টার মুছুন';

  @override
  String appsShownOf(int shown, int total) {
    return '$totalটির মধ্যে $shownটি অ্যাপ দেখাচ্ছে';
  }

  @override
  String uninstallSummaryOne(String size) {
    return 'একটি অ্যাপ মুছে $size জায়গা খালি হয়েছে';
  }

  @override
  String uninstallSummaryMany(String size, int count) {
    return '$countটি অ্যাপ মুছে $size জায়গা খালি হয়েছে';
  }

  @override
  String get deviceMemory => 'ডিভাইসের RAM';

  @override
  String get memoryUsed => 'RAM ব্যবহৃত';

  @override
  String get memoryTotal => 'মোট RAM';

  @override
  String get sortName => 'নাম';

  @override
  String get sortDate => 'তারিখ';

  @override
  String get sortSize => 'সাইজ';

  @override
  String get copyPackageName => 'প্যাকেজ নাম কপি করুন';

  @override
  String get copiedToClipboard => 'ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String uninstallManyWarning(int count) {
    return 'প্রতিটি অ্যাপের জন্য আলাদা নিশ্চিতকরণ লাগবে: একটানা $countটি ডায়ালগ';
  }

  @override
  String get worksOffline => 'অফলাইনে কাজ করে। কিছুই ফোনের বাইরে যায় না।';

  @override
  String get dismiss => 'মুছে দিন';

  @override
  String get clearRecentSearches => 'সাম্প্রতিক সার্চ মুছুন';

  @override
  String get ramNotStorage => 'RAM (কাজের মেমোরি) — স্টোরেজ নয়';

  @override
  String get madeBy => 'তৈরি করেছে KeshabStudios';

  @override
  String get storageFree => 'খালি স্টোরেজ';

  @override
  String get storageUsed => 'স্টোরেজ ব্যবহৃত';

  @override
  String get storageTotal => 'মোট স্টোরেজ';

  @override
  String get phoneStorage => 'ফোনের স্টোরেজ';

  @override
  String get storageNotRam => 'অ্যাপ ও ফাইলের জায়গা — RAM নয়';

  @override
  String get uninstallDone => 'পরিষ্কার সম্পন্ন';

  @override
  String uninstallKept(int count) {
    return '$countটি রাখা হয়েছে';
  }

  @override
  String get onboardingSkip => 'এড়িয়ে যান';

  @override
  String get onboardingNext => 'পরবর্তী';

  @override
  String get onboardingStart => 'শুরু করুন';

  @override
  String get onboardingWelcomeTitle => 'দরকারি জিনিসের জন্য জায়গা করুন';

  @override
  String get onboardingWelcomeBody =>
      'আপনার ডিভাইসে ইনস্টল করা অ্যাপ এক জায়গায় খুঁজুন ও পরিচালনা করুন।';

  @override
  String get onboardingManageTitle => 'সরানোর জন্য অ্যাপ খুঁজুন';

  @override
  String get onboardingManageBody =>
      'অ্যাপ খুঁজুন, সাজান ও নির্বাচন করুন। প্রতিটি আনইনস্টলের আগে Android আপনার নিশ্চিতকরণ চাইবে।';

  @override
  String get onboardingPrivacyTitle => 'নিয়ন্ত্রণ আপনার হাতেই';

  @override
  String get onboardingPrivacyBody =>
      'আপনার অ্যাপের তালিকা ডিভাইসেই থাকে। বিস্তারিত সাইজের জন্য usage access এবং নোটিফিকেশন ঐচ্ছিক।';
}

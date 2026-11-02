import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';

/// Both locales the app ships, read through the same delegates `main.dart`
/// installs, so a missing translation fails here instead of on a device.
Future<AppLocalizations> _localizations(
  WidgetTester tester,
  String languageCode,
) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  test('the app supports English and Bangla', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(<Locale>[const Locale('en'), const Locale('bn')]),
    );
  });

  testWidgets('Bangla is not silently falling back to English', (tester) async {
    final en = await _localizations(tester, 'en');
    final bn = await _localizations(tester, 'bn');

    expect(_digest(bn), isNot(_digest(en)));
    // The brand stays English in both, by design (docs/10 §2).
    expect(bn.appTitle, 'Goodbye Apps');
    expect(bn.uninstall, 'আনইনস্টল');
  });

  testWidgets('placeholders land in both languages', (tester) async {
    final en = await _localizations(tester, 'en');
    final bn = await _localizations(tester, 'bn');

    expect(
      [
        en.selectedCount(3),
        en.uninstallMany(7),
        en.tabUserApps(12),
        en.appsAndSize(2, '1.5 MB'),
        en.usedOfTotal('3.0 GB', '6.0 GB'),
        en.versionAndSize('1.0', '12.0 MB'),
      ],
      [
        '3 selected',
        'Uninstall 7 apps?',
        'User apps (12)',
        '2 apps • 1.5 MB',
        '3.0 GB / 6.0 GB used',
        'v1.0 • 12.0 MB',
      ],
    );

    expect(
      [
        bn.selectedCount(3),
        bn.uninstallMany(7),
        bn.tabUserApps(12),
        bn.appsAndSize(2, '1.5 MB'),
        bn.usedOfTotal('3.0 GB', '6.0 GB'),
      ],
      [
        '3টি নির্বাচিত',
        '7টি অ্যাপ আনইনস্টল করবেন?',
        'ইউজার অ্যাপ (12)',
        '2টি অ্যাপ • 1.5 MB',
        '3.0 GB / 6.0 GB ব্যবহৃত',
      ],
    );
  });
}

/// A sample of messages, joined — enough to notice a locale that never
/// differs from the template.
String _digest(AppLocalizations l10n) => [
  l10n.appTitle,
  l10n.loadingApps,
  l10n.searchApps,
  l10n.sort,
  l10n.uninstall,
  l10n.settings,
  l10n.theme,
  l10n.freeMemory,
  l10n.privacyPolicy,
  l10n.sendFeedback,
].join('\u0000');

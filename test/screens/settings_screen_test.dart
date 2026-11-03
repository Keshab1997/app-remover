import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';
import 'package:goodbye_apps/screens/settings_screen.dart';

/// The footer is a sign-off, so the test only asks that it is really rendered
/// at the bottom of the page, in both languages the app ships.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester, Locale locale) async {
    // A tall surface keeps every ListView child, footer included, on stage.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the studio credit sits at the bottom in English', (
    tester,
  ) async {
    await open(tester, const Locale('en'));

    expect(find.text('Made by KeshabStudios'), findsOneWidget);
    expect(find.text('Goodbye Apps'), findsOneWidget);
  });

  testWidgets('the studio credit is translated, the brand is not', (
    tester,
  ) async {
    await open(tester, const Locale('bn'));

    expect(find.text('তৈরি করেছে KeshabStudios'), findsOneWidget);
    expect(find.text('Goodbye Apps'), findsOneWidget);
  });
}

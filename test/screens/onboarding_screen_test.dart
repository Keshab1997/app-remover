import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';
import 'package:goodbye_apps/screens/onboarding_screen.dart';
import 'package:goodbye_apps/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.onboardingComplete.value = false;
  });

  testWidgets('next, swipe and get started complete onboarding', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(
          onComplete: () async {
            completed++;
          },
        ),
      ),
    );
    expect(find.text('Make space for what matters'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Find apps to remove'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('You stay in control'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('skip completes onboarding in Bangla', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );
    await tester.tap(find.text('এড়িয়ে যান'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  test('completion persists across settings reload', () async {
    await AppSettings.load();
    expect(AppSettings.onboardingComplete.value, isFalse);
    await AppSettings.completeOnboarding();
    AppSettings.onboardingComplete.value = false;
    await AppSettings.load();
    expect(AppSettings.onboardingComplete.value, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';
import 'package:goodbye_apps/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');
  late List<Map<String, dynamic>> rows;

  setUp(() {
    rows = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'listApps' => rows,
            'freeMemory' => const {'available': 1000, 'total': 4000},
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty list is still pull-to-refreshable', (tester) async {
    await open(tester);

    expect(find.text('Apps not found'), findsOneWidget);
    // The empty state's own copy tells the user to pull; that promise only
    // holds if a RefreshIndicator actually wraps it (docs/12 P0-1).
    expect(find.byType(RefreshIndicator), findsWidgets);
    expect(
      find.widgetWithText(FilledButton, 'Refresh'),
      findsOneWidget,
      reason: 'a tap fallback for a pull',
    );
  });

  testWidgets('a search with no hits offers to clear itself', (tester) async {
    rows = [
      {
        'packageName': 'com.example.maps',
        'label': 'Maps',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    await open(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nothing matches this');
    await tester.pumpAndSettle();

    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsWidgets);
  });
}

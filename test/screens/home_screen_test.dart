import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';
import 'package:goodbye_apps/models/app_info.dart';
import 'package:goodbye_apps/widgets/app_tile.dart';
import 'package:goodbye_apps/screens/home_screen.dart';
import 'package:goodbye_apps/services/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');
  late List<Map<String, dynamic>> rows;

  setUp(() {
    // AppSettings is static and HomeScreen writes the tab and the sort through
    // it, so a test that taps a tab would otherwise start the next one on that
    // tab - which is exactly the product behaviour being asserted, but not
    // what these tests mean.
    AppSettings.systemTab.value = false;
    AppSettings.sortField.value = SortField.size;
    AppSettings.sortAscending.value = false;
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

  /// `setSurfaceSize` resizes the render view but not the window metrics
  /// MediaQuery reads, and the breakpoint is a MediaQuery question.
  Future<void> resize(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    await tester.pump();
  }

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

  testWidgets('the first frame is a skeleton, not a blank pane', (
    tester,
  ) async {
    // Answer the first listApps only after a beat, so the loading state is
    // still on screen when we look at it (docs/12 P0-4).
    var release = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listApps') {
            while (!release) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            return <Map<String, dynamic>>[];
          }
          if (call.method == 'freeMemory') {
            return const {'available': 1000, 'total': 4000};
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Loading apps…'), findsOneWidget);
    expect(
      find.byType(Card),
      findsAtLeastNWidgets(6),
      reason: 'rows shaped like the real list',
    );

    release = true;
    await tester.pumpAndSettle();
    expect(find.text('Loading apps…'), findsNothing);
    expect(find.text('Apps not found'), findsOneWidget);
  });

  testWidgets('select all takes the tab on screen, with its count', (
    tester,
  ) async {
    rows = [
      {
        'packageName': 'com.example.games',
        'label': 'Games',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
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
      {
        'packageName': 'android.systemui',
        'label': 'SystemUI',
        'isSystem': true,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    await open(tester);

    // Long-press opens selection mode; the toolbar then promises a count for
    // the tab in view (docs/12 P0-5).
    await tester.longPress(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    expect(
      find.byTooltip('Select all 2 in User apps'),
      findsOneWidget,
      reason: 'the count in view, not a guess',
    );
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget, reason: 'both user apps');

    await tester.tap(find.text('System apps (1)'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Select all 1 in System apps'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('a filter chip empties the list and offers a way out', (
    tester,
  ) async {
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

    expect(find.text('Over 500 MB'), findsOneWidget);
    // The mock device never grants usage access, so the chip that needs the
    // stamps is not offered at all.
    expect(find.text('Not used in 90 days'), findsNothing);

    await tester.tap(find.text('Over 500 MB'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches these filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Nothing matches these filters'), findsNothing);
  });

  testWidgets('search is a search field, and the list counts what it shows', (
    tester,
  ) async {
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
      {
        'packageName': 'com.example.games',
        'label': 'Games',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    // The keyboard behaviour is a property of the scrolling list, and a phone
    // is what shows a ListView: the wide layout is a GridView.
    await resize(tester, 420);
    await open(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.search);
    expect(field.textCapitalization, TextCapitalization.none);
    expect(
      tester
          .widget<ListView>(find.byType(ListView).first)
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
      reason: 'the keyboard must not sit over the list',
    );

    expect(find.textContaining('Showing'), findsNothing);
    await tester.enterText(find.byType(TextField), 'map');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 2 apps'), findsOneWidget);
  });

  testWidgets(
    'no checkbox to tick while browsing, tap toggles once selecting',
    (tester) async {
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
        {
          'packageName': 'com.example.games',
          'label': 'Games',
          'isSystem': false,
          'sizeBytes': 100,
          'firstInstallTime': 1,
          'lastUpdateTime': 1,
          'versionName': '1.0',
          'versionCode': 1,
        },
      ];
      await open(tester);

      expect(
        find.byType(Checkbox),
        findsNothing,
        reason: 'a row is either opened or selected, not both at once',
      );

      await tester.longPress(find.text('Maps'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    },
  );

  testWidgets('the memory bar opens a sheet instead of a second refresh', (
    tester,
  ) async {
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

    // The bar used to ship its own 18 px refresh next to the app bar's.
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.text('Free memory'));
    await tester.pumpAndSettle();
    expect(find.text('Device memory'), findsOneWidget);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    // 4000 - 1000 bytes from the mocked ActivityManager.
    expect(find.text('2.9 KB / 3.9 KB used'), findsOneWidget);
  });

  testWidgets('sort moved out of the app bar into the list', (tester) async {
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

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsNWidgets(3),
      reason: 'search, refresh, settings - sort belongs to the list',
    );

    final chip = find.widgetWithText(ActionChip, 'Size');
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort by name'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Name'), findsOneWidget);
  });

  testWidgets('a 640 dp-wide list is two columns side by side', (tester) async {
    rows = [
      {
        'packageName': 'com.example.alpha',
        'label': 'Alpha',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.beta',
        'label': 'Beta',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.gamma',
        'label': 'Gamma',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.delta',
        'label': 'Delta',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    await resize(tester, 640);
    await open(tester);

    expect(find.byType(GridView), findsOneWidget);
    final left = tester.getRect(find.byType(Card).at(0));
    final right = tester.getRect(find.byType(Card).at(1));
    expect(right.top, left.top, reason: 'same row, two columns');
    expect(right.left, greaterThan(left.left));
  });

  testWidgets('a phone-width list stays a list', (tester) async {
    rows = [
      {
        'packageName': 'com.example.alpha',
        'label': 'Alpha',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.beta',
        'label': 'Beta',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.gamma',
        'label': 'Gamma',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
      {
        'packageName': 'com.example.delta',
        'label': 'Delta',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': 1,
        'lastUpdateTime': 1,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    await resize(tester, 420);
    await open(tester);

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('a fresh install is marked on the row', (tester) async {
    final recent = DateTime.now().subtract(const Duration(days: 2));
    rows = [
      {
        'packageName': 'com.example.maps',
        'label': 'Maps',
        'isSystem': false,
        'sizeBytes': 100,
        'firstInstallTime': recent.millisecondsSinceEpoch,
        'lastUpdateTime': recent.millisecondsSinceEpoch,
        'versionName': '1.0',
        'versionCode': 1,
      },
    ];
    await open(tester);

    expect(
      find.descendant(
        of: find.byType(AppTile),
        matching: find.text('Installed recently'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sheet copies the package name', (tester) async {
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

    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(find.text('com.example.maps'), findsWidgets);
    // The row is below the fold on a 600 px viewport, which is the point of the
    // sheet scrolling.
    await tester.ensureVisible(find.text('Copy package name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy package name'));
    await tester.pumpAndSettle();

    // The test binding's own clipboard fake does not hand the text back, so
    // this asserts the confirmation the user sees: the sheet closed and the
    // row reported what it did.
    expect(find.text('Copied to clipboard'), findsOneWidget);
    expect(find.text('Copy package name'), findsNothing);
  });

  testWidgets('a batch confirms in the bar instead of another dialog', (
    tester,
  ) async {
    rows = [
      for (var i = 0; i < 30; i++)
        {
          'packageName': 'com.example.app$i',
          'label': 'App $i',
          'isSystem': false,
          'sizeBytes': 100,
          'firstInstallTime': 1,
          'lastUpdateTime': 1,
          'versionName': '1.0',
          'versionCode': 1,
        },
    ];
    await open(tester);

    await tester.longPress(find.text('App 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    await tester.pumpAndSettle();

    // The bar becomes the question: no modal, but no accidental 30-app run
    // either (docs/12 P2-15).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Uninstall 30 apps?'), findsOneWidget);
    expect(
      find.text('The system will ask you to confirm each uninstall.'),
      findsOneWidget,
    );
    expect(
      find.text('Each app asks for its own confirmation: 30 dialogs in a row'),
      findsOneWidget,
    );
  });

  testWidgets('one app costs one tap and one popup: the system one', (
    tester,
  ) async {
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

    await tester.longPress(find.text('Maps'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    // The controller waits out the gap Android needs between dialogs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tap again to confirm'), findsNothing);
    // The fake device reports the system dialog as declined, which is now
    // visible instead of a silent return to the list.
    expect(find.text('No apps were removed'), findsOneWidget);
  });

  testWidgets('search remembers what you typed', (tester) async {
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
    await tester.enterText(find.byType(TextField), 'map');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Leave search and come back: the query is offered as a chip, and one tap
    // puts it back in the field.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'map'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear_all));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'map'), findsNothing);
  });

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

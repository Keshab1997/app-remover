import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/models/app_info.dart';
import 'package:goodbye_apps/services/settings.dart';
import 'package:goodbye_apps/state/apps_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the Kotlin side answers for `listApps`. `setUp` copies it into a
/// mutable list so a test can change the device between loads.
final List<Map<String, dynamic>> _deviceRows = [
  {
    'packageName': 'com.example.games',
    'label': 'Games',
    'isSystem': false,
    'sizeBytes': 300,
    'firstInstallTime': 1000,
    'lastUpdateTime': 1000,
    'versionName': '1.0',
    'versionCode': 1,
  },
  {
    'packageName': 'com.example.maps',
    'label': 'Maps',
    'isSystem': false,
    'sizeBytes': 100,
    'firstInstallTime': 2000,
    'lastUpdateTime': 9000,
    'versionName': '1.0',
    'versionCode': 1,
  },
  {
    'packageName': 'com.example.camera',
    'label': 'Camera',
    'isSystem': false,
    'sizeBytes': 200,
    'firstInstallTime': 8000,
    'lastUpdateTime': 2000,
    'versionName': '1.0',
    'versionCode': 1,
  },
  {
    'packageName': 'android.systemui',
    'label': 'SystemUI',
    'isSystem': true,
    'sizeBytes': 999,
    'firstInstallTime': 1000,
    'lastUpdateTime': 1000,
    'versionName': '1.0',
    'versionCode': 1,
  },
  {
    // No package name: dropped by the service before the controller sees it.
    'label': 'Ghost',
  },
  {
    // Icons are not part of the row any more (docs/07).
    'packageName': 'com.example.iconless',
    'label': 'Iconless',
    'isSystem': false,
    'sizeBytes': 1,
    'icon': 'leftover from an older build',
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');
  late List<Map<String, dynamic>> rows;
  late AppsController controller;

  setUp(() {
    // AppSettings holds the sort in a static notifier, and AppsController
    // starts from it, so a test that sorts cannot leak its order into the next.
    AppSettings.sortField.value = SortField.size;
    AppSettings.sortAscending.value = false;
    AppSettings.systemTab.value = false;
    rows = List.of(_deviceRows);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'listApps' => rows,
            'freeMemory' => const {'available': 1000, 'total': 4000},
            _ => null,
          };
        });
    controller = AppsController();
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('load fills both tabs and the RAM readout', () async {
    expect(controller.loading, isTrue);

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.failure, isNull);
    expect(controller.installedCount, 5);
    expect(controller.appsFor(system: true).map((a) => a.packageName), [
      'android.systemui',
    ]);
    expect(controller.freeRam, 1000);
    expect(controller.totalRam, 4000);
  });

  test('a channel failure is reported without throwing', () async {
    rows = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'dead');
        });

    await controller.load();

    expect(controller.failure, AppLoadFailure.listUnavailable);
    expect(controller.installedCount, 0);
    expect(controller.loading, isFalse);
  });

  test(
    'a bulk uninstall walks the selection and counts the space it bought',
    () async {
      await controller.load();

      final asked = <String>[];
      final reported = <int>[];
      controller.addListener(() {
        final progress = controller.uninstallProgress;
        if (progress != null) reported.add(progress.done);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listApps') return rows;
            if (call.method == 'freeMemory') {
              return const {'available': 1000, 'total': 4000};
            }
            if (call.method == 'uninstall') {
              final package = call.arguments['package'] as String;
              asked.add(package);
              // Maps is the one the user declines in the system dialog.
              return package != 'com.example.maps';
            }
            return null;
          });

      controller
        ..toggleSelected('com.example.games')
        ..toggleSelected('com.example.maps');

      final summary = await controller.uninstallSelected();

      expect(asked, ['com.example.games', 'com.example.maps']);
      // Only the accepted package counts, and only its size is freed.
      expect(summary?.removed, 1);
      expect(summary?.freedBytes, 300);
      expect(summary?.failed, 1);
      // The sheet can render "removing 2 of 2" only if the run said so first.
      expect(reported, [0, 1]);
      expect(controller.uninstallProgress, isNull);
      expect(controller.selected, isEmpty);
      expect(controller.uninstalling, isFalse);
    },
  );

  test('a bulk uninstall with nothing selected does not start', () async {
    await controller.load();

    expect(await controller.uninstallSelected(), isNull);
    expect(controller.uninstalling, isFalse);
  });

  test('the list opens with the biggest app first', () async {
    await controller.load();

    // The default is the question the app answers: what is worth removing.
    expect(controller.sortField, SortField.size);
    expect(controller.ascending, isFalse);
    expect(controller.appsFor(system: false).map((a) => a.sizeBytes), [
      300,
      200,
      100,
      1,
    ]);
  });

  test('a chosen sort is written to the store', () async {
    SharedPreferences.setMockInitialValues({});
    await controller.load();

    controller.setSort(SortField.date, ascending: true);
    // setSort fires the write without awaiting it, so the list repaints
    // before the store is asked to remember.
    await pumpEventQueue();

    expect(AppSettings.sortField.value, SortField.date);
    expect(AppSettings.sortAscending.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sort_field'), 'date');
    expect(prefs.getBool('sort_ascending'), isTrue);
  });

  test('currentApps follows the tab the controller was told about', () async {
    await controller.load();
    controller.setSort(SortField.name, ascending: true);

    expect(controller.systemTab, isFalse);
    expect(controller.currentApps.map((a) => a.label), [
      'Camera',
      'Games',
      'Iconless',
      'Maps',
    ]);

    controller.setSystemTab(true);
    expect(controller.currentApps.map((a) => a.label), ['SystemUI']);
  });

  test('name sort ignores case and follows the direction', () async {
    await controller.load();
    controller.setSort(SortField.name, ascending: true);

    expect(controller.appsFor(system: false).map((a) => a.label), [
      'Camera',
      'Games',
      'Iconless',
      'Maps',
    ]);

    controller.toggleSortOrder();
    expect(controller.appsFor(system: false).map((a) => a.label), [
      'Maps',
      'Iconless',
      'Games',
      'Camera',
    ]);
  });

  test('date sort uses the newest of install and update', () async {
    await controller.load();
    controller.setSort(SortField.date, ascending: true);

    expect(controller.appsFor(system: false).map((a) => a.packageName), [
      'com.example.iconless', // no timestamps at all -> epoch
      'com.example.games', // both stamps 1000
      'com.example.camera', // installed 8000, updated 2000
      'com.example.maps', // updated 9000
    ]);
  });

  test('size sort orders by bytes', () async {
    await controller.load();
    controller.setSort(SortField.size, ascending: true);

    expect(controller.appsFor(system: false).map((a) => a.sizeBytes), [
      1,
      100,
      200,
      300,
    ]);
  });

  test('a filter chip narrows the tab and a second tap releases it', () async {
    await controller.load();

    controller.setFilter(AppFilter.large);
    expect(controller.filter, AppFilter.large);
    // Nothing in the fake device is 500 MiB, so the honest answer is empty.
    expect(controller.appsFor(system: false), isEmpty);
    expect(controller.appsFor(system: true), isEmpty);

    controller.setFilter(AppFilter.large);
    expect(controller.filter, isNull, reason: 'same chip toggles off');
    expect(controller.appsFor(system: false).length, 4);
  });

  test('the unused filter is dropped when usage access is off', () async {
    await controller.load();
    controller.setFilter(AppFilter.unused);
    expect(controller.usageAvailable, isFalse);

    await controller.load();

    // A filter the device cannot answer must not sit there emptying the list.
    expect(controller.filter, isNull);
    expect(controller.appsFor(system: false).length, 4);
  });

  test('clearFilters releases the list', () async {
    await controller.load();
    controller.setFilter(AppFilter.large);
    expect(controller.narrowing, isTrue);

    controller.clearFilters();

    expect(controller.filter, isNull);
    expect(controller.narrowing, isFalse);
  });

  test('the query filters both tabs', () async {
    await controller.load();
    controller.setQuery('MAP');

    expect(controller.appsFor(system: false).map((a) => a.label), ['Maps']);
    expect(controller.appsFor(system: true), isEmpty);

    controller.setQuery('');
    expect(controller.appsFor(system: false).length, 4);
  });

  test('selection tracks the batch size', () async {
    await controller.load();

    controller.toggleSelected('com.example.maps');
    controller.toggleSelected('com.example.games');
    expect(controller.selectionMode, isTrue);
    expect(controller.selectedSize, 400);

    controller.toggleSelected('com.example.maps');
    expect(controller.selectedSize, 300);

    controller.selectAll(controller.appsFor(system: false));
    expect(controller.selected.length, 4);

    controller.clearSelection();
    expect(controller.selectionMode, isFalse);
    expect(controller.selectedSize, 0);
  });

  test('a settled list is reused until a list input actually changes', () async {
    await controller.load();
    final first = controller.appsFor(system: false);

    // Two tab counts, select-all and the visible list all ask in one build.
    expect(identical(first, controller.appsFor(system: false)), isTrue);
    // A selection tap repaints the screen; it must not re-sort 200 apps.
    controller.toggleSelected('com.example.maps');
    expect(identical(first, controller.appsFor(system: false)), isTrue);

    controller.setQuery('map');
    expect(identical(first, controller.appsFor(system: false)), isFalse);
    expect(controller.appsFor(system: false).length, 1);
  });

  test('selection drops packages that are gone after a reload', () async {
    await controller.load();
    controller.toggleSelected('com.example.games');
    controller.toggleSelected('com.example.maps');

    await controller.load(); // still installed -> still selected
    expect(controller.selected, contains('com.example.games'));

    rows.removeWhere(
      (row) => row['packageName'] == 'com.example.games',
    ); // uninstalled out from under us
    await controller.load();

    expect(controller.selected, ['com.example.maps']);
    expect(controller.installedCount, 4);
  });
}

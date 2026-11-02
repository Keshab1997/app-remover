import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/models/app_info.dart';
import 'package:goodbye_apps/state/apps_controller.dart';

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
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');
  late List<Map<String, dynamic>> rows;
  late AppsController controller;

  setUp(() {
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
    expect(controller.error, isNull);
    expect(controller.installedCount, 4);
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

    expect(controller.error, 'Could not read the installed app list.');
    expect(controller.installedCount, 0);
    expect(controller.loading, isFalse);
  });

  test('name sort ignores case and follows the direction', () async {
    await controller.load();

    expect(controller.appsFor(system: false).map((a) => a.label), [
      'Camera',
      'Games',
      'Maps',
    ]);

    controller.toggleSortOrder();
    expect(controller.appsFor(system: false).map((a) => a.label), [
      'Maps',
      'Games',
      'Camera',
    ]);
  });

  test('date sort uses the newest of install and update', () async {
    await controller.load();
    controller.setSort(SortField.date);

    expect(controller.appsFor(system: false).map((a) => a.packageName), [
      'com.example.games', // both stamps 1000
      'com.example.camera', // installed 8000, updated 2000
      'com.example.maps', // updated 9000
    ]);
  });

  test('size sort orders by bytes', () async {
    await controller.load();
    controller.setSort(SortField.size);

    expect(controller.appsFor(system: false).map((a) => a.sizeBytes), [
      100,
      200,
      300,
    ]);
  });

  test('the query filters both tabs', () async {
    await controller.load();
    controller.setQuery('MAP');

    expect(controller.appsFor(system: false).map((a) => a.label), ['Maps']);
    expect(controller.appsFor(system: true), isEmpty);

    controller.setQuery('');
    expect(controller.appsFor(system: false).length, 3);
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
    expect(controller.selected.length, 3);

    controller.clearSelection();
    expect(controller.selectionMode, isFalse);
    expect(controller.selectedSize, 0);
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
    expect(controller.installedCount, 3);
  });
}

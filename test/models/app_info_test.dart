import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/models/app_info.dart';

AppInfo _app({
  String packageName = 'com.example.app',
  String label = 'Example',
  bool isSystem = false,
  int sizeBytes = 0,
  int firstInstallTime = 0,
  int lastUpdateTime = 0,
}) {
  return AppInfo(
    packageName: packageName,
    label: label,
    isSystem: isSystem,
    sizeBytes: sizeBytes,
    firstInstallTime: firstInstallTime,
    lastUpdateTime: lastUpdateTime,
    versionName: '1.0',
    versionCode: 1,
  );
}

void main() {
  group('AppInfo.fromMap', () {
    test('reads every field the Kotlin side sends', () {
      final app = AppInfo.fromMap({
        'packageName': 'com.example.app',
        'label': 'Example',
        'isSystem': true,
        'sizeBytes': 2048,
        'firstInstallTime': 1000,
        'lastUpdateTime': 2000,
        'versionName': '2.1',
        'versionCode': 21,
      });

      expect(app.packageName, 'com.example.app');
      expect(app.label, 'Example');
      expect(app.isSystem, isTrue);
      expect(app.sizeBytes, 2048);
      expect(app.versionName, '2.1');
      expect(app.versionCode, 21);
    });

    test('falls back to safe defaults for absent keys', () {
      // NativeApps.listApps drops entries with an empty packageName, so a
      // half-populated map must not throw on the platform thread.
      final app = AppInfo.fromMap({'packageName': 'com.example.app'});

      expect(app.label, '');
      expect(app.isSystem, isFalse);
      expect(app.sizeBytes, 0);
      expect(app.versionCode, 0);
    });
  });

  test('the list row no longer carries icon bytes', () {
    // docs/07 moved icons out of listApps; a stray key must not resurrect it.
    expect(
      AppInfo.fromMap({'packageName': 'a', 'icon': 'bytes'}).packageName,
      'a',
    );
  });

  group('changedAt', () {
    test('is the update when the app was updated after install', () {
      final app = _app(firstInstallTime: 1000, lastUpdateTime: 5000);
      expect(app.changedAt, app.updatedAt);
    });

    test('is the install for a never-updated app', () {
      final app = _app(firstInstallTime: 5000, lastUpdateTime: 5000);
      expect(app.changedAt, app.installedAt);
    });
  });

  group('matches', () {
    test('an empty query keeps everything', () {
      expect(_app().matches(''), isTrue);
    });

    test('is case insensitive across label and package', () {
      final app = _app(label: 'Camera', packageName: 'com.android.camera');
      expect(app.matches('CAMERA'), isTrue);
      expect(app.matches('android.cam'), isTrue);
      expect(app.matches('gallery'), isFalse);
    });
  });

  group('formatBytes', () {
    test('zero and negative sizes read as 0 B', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-5), '0 B');
    });

    test('one decimal below 100 of a unit, none at or above', () {
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(12 * 1024 * 1024), '12.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('hundreds and bare bytes drop the decimal', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(120 * 1024 * 1024), '120 MB');
    });
  });

  group('formatDate', () {
    test('today and yesterday are relative', () {
      final now = DateTime.now();
      expect(formatDate(now), 'Today');
      expect(
        formatDate(DateTime(now.year, now.month, now.day - 1)),
        'Yesterday',
      );
    });

    test('earlier this year shows day and month, no year', () {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final now = DateTime.now();
      final day = DateTime(now.year, 3, 7).isBefore(now)
          ? DateTime(now.year, 3, 7)
          : DateTime(now.year, 1, 7);
      expect(formatDate(day), '${day.day} ${months[day.month - 1]}');
    });

    test('a previous year is shown in full', () {
      final year = DateTime.now().year - 1;
      expect(formatDate(DateTime(year, 11, 3)), '3 Nov $year');
    });
  });
}

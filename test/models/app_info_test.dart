import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/models/app_info.dart';

AppInfo _app({
  String packageName = 'com.example.app',
  String label = 'Example',
  bool isSystem = false,
  int sizeBytes = 0,
  int firstInstallTime = 0,
  int lastUpdateTime = 0,
  int? lastUsedAt,
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
    lastUsedAt: lastUsedAt,
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

    test('carries the last-opened stamp, and its absence', () {
      final Map<String, dynamic> row = {
        'packageName': 'com.example.app',
        'label': 'Example',
        'isSystem': false,
        'sizeBytes': 1,
        'firstInstallTime': 0,
        'lastUpdateTime': 0,
        'versionName': '1.0',
        'versionCode': 1,
      };

      expect(AppInfo.fromMap(row).lastUsedAt, isNull);

      row['lastTimeUsed'] = 5000;
      expect(AppInfo.fromMap(row).lastUsedAt, 5000);
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
  group('AppFilter', () {
    final now = DateTime.utc(2026, 11, 3);
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    test('unused covers the stale and the never-opened', () {
      expect(
        AppFilter.unused.matches(
          _app(lastUsedAt: daysAgo(120).millisecondsSinceEpoch),
          now: now,
        ),
        isTrue,
      );
      expect(
        AppFilter.unused.matches(
          _app(lastUsedAt: daysAgo(4).millisecondsSinceEpoch),
          now: now,
        ),
        isFalse,
      );
      // No bucket in the yearly stats is the strongest signal there is.
      expect(AppFilter.unused.matches(_app(), now: now), isTrue);
    });

    test('large starts at 500 MiB', () {
      expect(
        AppFilter.large.matches(_app(sizeBytes: AppFilter.largeBytes - 1)),
        isFalse,
      );
      expect(
        AppFilter.large.matches(_app(sizeBytes: AppFilter.largeBytes)),
        isTrue,
      );
    });

    test('recent is the fortnight after an install', () {
      expect(
        AppFilter.recent.matches(
          _app(firstInstallTime: daysAgo(3).millisecondsSinceEpoch),
          now: now,
        ),
        isTrue,
      );
      expect(
        AppFilter.recent.matches(
          _app(firstInstallTime: daysAgo(40).millisecondsSinceEpoch),
          now: now,
        ),
        isFalse,
      );
    });
  });
  group('installedRecently', () {
    final now = DateTime.utc(2026, 11, 3);

    test('is a week, not a fortnight', () {
      expect(
        _app(
          firstInstallTime: now
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
        ).installedRecently(now: now),
        isTrue,
      );
      expect(
        _app(
          firstInstallTime: now
              .subtract(const Duration(days: 9))
              .millisecondsSinceEpoch,
        ).installedRecently(now: now),
        isFalse,
      );
    });

    test('an unknown install date is not recent', () {
      expect(_app().installedRecently(now: now), isFalse);
    });
  });
}

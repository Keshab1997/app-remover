/// A single installed application as reported by the Android package manager.
///
/// Icons are not part of this record — they are fetched per visible row by
/// `IconStore` (docs/07), so a 200-app list does not decode 200 PNGs first.
class AppInfo {
  const AppInfo({
    required this.packageName,
    required this.label,
    required this.isSystem,
    required this.sizeBytes,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.versionName,
    required this.versionCode,
    this.lastUsedAt,
  });

  final String packageName;
  final String label;
  final bool isSystem;
  final int sizeBytes;
  final int firstInstallTime;
  final int lastUpdateTime;
  final String versionName;
  final int versionCode;

  /// When the launcher last brought the app to the foreground, in epoch ms, or
  /// `null` when usage access is off or no bucket covers it. `null` with usage
  /// access granted means "not opened in the last year" - the answer the
  /// filters want, not a missing value (docs/12 P1-7).
  final int? lastUsedAt;

  DateTime get installedAt =>
      DateTime.fromMillisecondsSinceEpoch(firstInstallTime);

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(lastUpdateTime);

  /// Newest of install/update, used for the "Date" sort.
  DateTime get changedAt =>
      updatedAt.isAfter(installedAt) ? updatedAt : installedAt;

  factory AppInfo.fromMap(dynamic raw) {
    final map = (raw as Map).cast<String, dynamic>();
    return AppInfo(
      packageName: map['packageName'] as String? ?? '',
      label: map['label'] as String? ?? '',
      isSystem: map['isSystem'] as bool? ?? false,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      firstInstallTime: (map['firstInstallTime'] as num?)?.toInt() ?? 0,
      lastUpdateTime: (map['lastUpdateTime'] as num?)?.toInt() ?? 0,
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      lastUsedAt: (map['lastTimeUsed'] as num?)?.toInt(),
    );
  }

  /// Installed inside [within]. The row says so, because a package that landed
  /// this week raises "is this mine?" - and that is worth answering without
  /// opening anything (docs/12 P2-14).
  bool installedRecently({
    Duration within = const Duration(days: 7),
    DateTime? now,
  }) {
    if (firstInstallTime <= 0) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(firstInstallTime);
    return (now ?? DateTime.now()).difference(at) <= within;
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        packageName.toLowerCase().contains(needle);
  }
}

enum SortField { name, date, size }

/// A question the list can be narrowed to. Each one is a reason to uninstall,
/// which is the only reason a user opens an app like this.
enum AppFilter {
  /// Not opened in the last 90 days - or, with usage access on, not opened in
  /// the whole year the stats cover.
  unused,

  /// Big enough that removing it is worth a tap.
  large,

  /// Installed in the last two weeks, i.e. still being decided about.
  recent;

  /// Bytes `large` starts at: 500 MiB, matching how [formatBytes] spells MB.
  static const largeBytes = 500 << 20;

  static const unusedWindow = Duration(days: 90);
  static const recentWindow = Duration(days: 14);

  bool matches(AppInfo app, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final lastUsed = app.lastUsedAt;
    return switch (this) {
      unused =>
        // Without a stamp the only honest reading is "has not been opened in
        // the window the stats cover", which is what this filter asks.
        lastUsed == null ||
            at.difference(DateTime.fromMillisecondsSinceEpoch(lastUsed)) >
                unusedWindow,
      large => app.sizeBytes >= largeBytes,
      recent => at.difference(app.installedAt) <= recentWindow,
    };
  }
}

/// Human readable byte size, e.g. 12.4 MB.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
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
  final base = '${date.day} ${months[date.month - 1]}';
  return date.year == now.year ? base : '$base ${date.year}';
}

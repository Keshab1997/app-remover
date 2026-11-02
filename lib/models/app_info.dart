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
  });

  final String packageName;
  final String label;
  final bool isSystem;
  final int sizeBytes;
  final int firstInstallTime;
  final int lastUpdateTime;
  final String versionName;
  final int versionCode;

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
    );
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        packageName.toLowerCase().contains(needle);
  }
}

enum SortField { name, date, size }

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

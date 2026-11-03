import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_info.dart';
import '../services/native_apps.dart';

/// Why the list could not be shown. The words belong to the widget layer:
/// only `AppLocalizations` knows which language to say them in (docs/10).
enum AppLoadFailure { listUnavailable }

class AppsController extends ChangeNotifier {
  AppsController() {
    _subscription = NativeApps.packageChanges().listen((_) => load());
  }

  StreamSubscription<String>? _subscription;

  List<AppInfo> _all = [];
  bool _loading = true;
  AppLoadFailure? _failure;
  String _query = '';
  SortField _sortField = SortField.name;
  bool _ascending = true;
  final Set<String> _selected = {};
  int _freeRam = 0;
  int _totalRam = 0;

  bool get loading => _loading;
  AppLoadFailure? get failure => _failure;
  String get query => _query;
  SortField get sortField => _sortField;
  bool get ascending => _ascending;
  Set<String> get selected => _selected;
  bool get selectionMode => _selected.isNotEmpty;
  int get freeRam => _freeRam;
  int get totalRam => _totalRam;
  int get installedCount => _all.length;

  List<AppInfo> appsFor({required bool system}) {
    final filtered = _all.where(
      (app) => app.isSystem == system && app.matches(_query),
    );
    final list = filtered.toList();
    list.sort((a, b) {
      final int result = switch (_sortField) {
        SortField.name => a.label.toLowerCase().compareTo(
          b.label.toLowerCase(),
        ),
        SortField.date => a.changedAt.compareTo(b.changedAt),
        SortField.size => a.sizeBytes.compareTo(b.sizeBytes),
      };
      return _ascending ? result : -result;
    });
    return list;
  }

  int get selectedSize => _all
      .where((app) => _selected.contains(app.packageName))
      .fold(0, (sum, app) => sum + app.sizeBytes);

  Future<void> load() async {
    _loading = true;
    _failure = null;
    notifyListeners();
    try {
      final apps = await NativeApps.listApps();
      _all = apps;
      _selected.removeWhere(
        (pkg) => !_all.any((app) => app.packageName == pkg),
      );
      await refreshMemory();
    } catch (e) {
      _failure = AppLoadFailure.listUnavailable;
      _all = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMemory() async {
    try {
      final memory = await NativeApps.freeMemory();
      _freeRam = memory.available;
      _totalRam = memory.total;
      notifyListeners();
    } catch (_) {
      // Ignore: memory readout is informational only.
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setSort(SortField field, {bool? ascending}) {
    _sortField = field;
    if (ascending != null) _ascending = ascending;
    notifyListeners();
  }

  void toggleSortOrder() {
    _ascending = !_ascending;
    notifyListeners();
  }

  void toggleSelected(String packageName) {
    if (!_selected.remove(packageName)) {
      _selected.add(packageName);
    }
    notifyListeners();
  }

  void selectAll(List<AppInfo> visible) {
    _selected.addAll(visible.map((app) => app.packageName));
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  Future<bool> uninstall(AppInfo app) => NativeApps.uninstall(app.packageName);

  bool _uninstalling = false;
  UninstallProgress? _progress;

  /// True while a bulk uninstall is waiting on system dialogs.
  bool get uninstalling => _uninstalling;

  /// Which package the run is on, or `null` when none is running.
  UninstallProgress? get uninstallProgress => _progress;

  /// Removes every selected package and reports what the run achieved.
  ///
  /// A bulk uninstall is the one place where the user commits to several
  /// system dialogs in a row, so the run says which one is in front of them
  /// and, at the end, how much space it actually bought (docs/12 P0-3).
  /// Returns `null` when there was nothing to do.
  Future<UninstallSummary?> uninstallSelected() async {
    if (_uninstalling || _selected.isEmpty) return null;
    final targets = _all
        .where((app) => _selected.contains(app.packageName))
        .toList(growable: false);
    _uninstalling = true;
    var done = 0;
    var failed = 0;
    var freedBytes = 0;
    try {
      for (final app in targets) {
        _progress = UninstallProgress(
          done: done,
          total: targets.length,
          freedBytes: freedBytes,
        );
        notifyListeners();
        // "Accepted" only means the system dialog was shown, so the reload
        // afterwards - not this bool - decides what the list looks like.
        if (await uninstall(app)) {
          done++;
          freedBytes += app.sizeBytes;
        } else {
          failed++;
        }
        // The system shows one confirmation dialog at a time; give it a moment.
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      _selected.clear();
      _progress = null;
      await load();
      return UninstallSummary(
        removed: done,
        freedBytes: freedBytes,
        failed: failed,
      );
    } finally {
      _progress = null;
      _uninstalling = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Which package a bulk uninstall is on right now.
class UninstallProgress {
  const UninstallProgress({
    required this.done,
    required this.total,
    required this.freedBytes,
  });

  final int done;
  final int total;
  final int freedBytes;
}

/// What a finished bulk uninstall achieved. A package the user rejected in the
/// system dialog counts as `failed`, not as `removed`.
class UninstallSummary {
  const UninstallSummary({
    required this.removed,
    required this.freedBytes,
    required this.failed,
  });

  final int removed;
  final int freedBytes;
  final int failed;
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_info.dart';
import '../services/native_apps.dart';
import '../services/settings.dart';

/// Why the list could not be shown. The words belong to the widget layer:
/// only `AppLocalizations` knows which language to say them in (docs/10).
enum AppLoadFailure { listUnavailable }

/// An installed app plus the primitive keys the list needs: a lower-cased name
/// for sorting, a lower-cased label/package pair for searching, and the newest
/// install/update stamp as an int instead of two `DateTime` objects.
typedef _AppRow =
    ({
      AppInfo app,
      String name,
      int date,
      String search,
    });

class AppsController extends ChangeNotifier {
  AppsController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _subscription = NativeApps.packageChanges().listen((_) => load());
  }

  StreamSubscription<String>? _subscription;

  List<AppInfo> _all = [];
  /// One row per installed app with its sort/search keys already computed.
  /// `appsFor` used to call `toLowerCase()` and build two `DateTime`s *inside*
  /// the sort comparator, so a 200-app list allocated thousands of objects on
  /// every rebuild. The keys are made once, when the device list arrives.
  List<_AppRow> _rows = const [];
  bool _loading = true;
  AppLoadFailure? _failure;
  String _query = '';
  final DateTime Function() _clock;
  AppFilter? _filter;
  bool _usageAvailable = false;

  /// Bumped only by the inputs `appsFor` reads. Selection taps, tab swipes and
  /// RAM refreshes repaint the screen but must never re-sort the whole list.
  int _revision = 0;
  int _builtRevision = -1;
  List<AppInfo>? _userApps;
  List<AppInfo>? _systemApps;

  void _listsChanged() => _revision++;
  // Largest first: the list exists so the user can find what to remove, and
  // size is the ordering that answers that. Both are restored from the store,
  // so a person who sorts differently once keeps it (docs/12 P1-6).
  SortField _sortField = AppSettings.sortField.value;
  bool _ascending = AppSettings.sortAscending.value;
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

  /// Whether the last-opened stamps came with the list, i.e. whether the
  /// "not used in 90 days" chip can be answered at all.
  bool get usageAvailable => _usageAvailable;

  AppFilter? get filter => _filter;

  /// Anything at all narrowing the list, which the empty state reads to decide
  /// whether to blame the search box or the filters.
  bool get narrowing => _query.isNotEmpty || _filter != null;

  void setFilter(AppFilter value) {
    // Tapping the chip that is already on turns it off: a filter with no way
    // out is a trap on a 200-row list.
    _filter = _filter == value ? null : value;
    _listsChanged();
    notifyListeners();
  }

  void clearFilters() {
    if (_filter == null) return;
    _filter = null;
    _listsChanged();
    notifyListeners();
  }

  /// Both tabs, filtered and sorted, computed together once per state change.
  /// The home screen asks for `appsFor` four times per build (two tab counts,
  /// the select-all size and the visible list); this makes the other three
  /// answers free instead of three more full sorts.
  List<AppInfo> appsFor({required bool system}) {
    if (_builtRevision != _revision) _buildLists();
    return system ? _systemApps! : _userApps!;
  }

  void _buildLists() {
    final needle = _query.toLowerCase();
    final filter = _filter;
    final now = _clock();
    final user = <_AppRow>[];
    final systemRows = <_AppRow>[];
    for (final row in _rows) {
      if (!row.search.contains(needle)) continue;
      if (filter != null && !filter.matches(row.app, now: now)) continue;
      (row.app.isSystem ? systemRows : user).add(row);
    }

    int compare(_AppRow a, _AppRow b) {
      final int result = switch (_sortField) {
        SortField.name => a.name.compareTo(b.name),
        SortField.date => a.date.compareTo(b.date),
        SortField.size => a.app.sizeBytes.compareTo(b.app.sizeBytes),
      };
      return _ascending ? result : -result;
    }

    user.sort(compare);
    systemRows.sort(compare);
    _userApps = user.map((row) => row.app).toList(growable: false);
    _systemApps = systemRows.map((row) => row.app).toList(growable: false);
    _builtRevision = _revision;
  }

  /// Which tab the user is looking at, kept here so that the widgets around
  /// the list - the tab labels, "select all" - all agree on one answer.
  /// Reading `TabController.index` at tap time is not enough: mid-swipe it
  /// can still name the page being scrolled away from (docs/12 P0-5).
  bool _systemTab = AppSettings.systemTab.value;
  bool get systemTab => _systemTab;

  void setSystemTab(bool value) {
    if (_systemTab == value) return;
    _systemTab = value;
    notifyListeners();
    unawaited(AppSettings.setSystemTab(value));
  }

  /// Everything the current tab shows, query and sort applied.
  List<AppInfo> get currentApps => appsFor(system: _systemTab);

  int get selectedSize => _all
      .where((app) => _selected.contains(app.packageName))
      .fold(0, (sum, app) => sum + app.sizeBytes);

  Future<void> load() async {
    _loading = true;
    _failure = null;
    notifyListeners();
    try {
      // Three independent channel reads. They used to run one after another,
      // so the two informational round trips sat on the critical path of the
      // first frame for no reason. `Future.wait` also handles the case where
      // more than one of them fails.
      final results = await Future.wait<dynamic>([
        NativeApps.listApps(),
        _hasUsageAccess(),
        NativeApps.freeMemory(),
      ]);
      final apps = results[0] as List<AppInfo>;
      _all = apps;
      _rows = apps
          .map(
            (app) => (
              app: app,
              name: app.label.toLowerCase(),
              // Same answer as AppInfo.changedAt, without four DateTime
              // allocations per comparison.
              date: app.lastUpdateTime > app.firstInstallTime
                  ? app.lastUpdateTime
                  : app.firstInstallTime,
              search:
                  '${app.label.toLowerCase()}\n${app.packageName.toLowerCase()}',
            ),
          )
          .toList(growable: false);
      _usageAvailable = results[1] as bool;
      _setMemory(results[2] as ({int available, int total}));
      // Access revoked since the chip was tapped must not leave the list
      // looking empty for a reason the user cannot act on.
      if (!_usageAvailable && _filter == AppFilter.unused) _filter = null;
      _selected.removeWhere(
        (pkg) => !_all.any((app) => app.packageName == pkg),
      );
      _listsChanged();
    } catch (e) {
      _failure = AppLoadFailure.listUnavailable;
      _all = [];
      _rows = const [];
      _listsChanged();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Never lets the informational check below fail the whole load; on a
  /// platform with no channel there is simply no answer.
  Future<bool> _hasUsageAccess() async {
    try {
      return await NativeApps.hasUsageAccess();
    } catch (_) {
      return false;
    }
  }

  void _setMemory(({int available, int total}) memory) {
    _freeRam = memory.available;
    _totalRam = memory.total;
  }

  Future<void> refreshMemory() async {
    try {
      _setMemory(await NativeApps.freeMemory());
      notifyListeners();
    } catch (_) {
      // Ignore: memory readout is informational only.
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _listsChanged();
    notifyListeners();
  }

  void setSort(SortField field, {bool? ascending}) {
    _sortField = field;
    if (ascending != null) _ascending = ascending;
    _listsChanged();
    notifyListeners();
    _rememberSort();
  }

  void toggleSortOrder() {
    _ascending = !_ascending;
    _listsChanged();
    notifyListeners();
    _rememberSort();
  }

  void _rememberSort() =>
      unawaited(AppSettings.setSort(_sortField, _ascending));

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

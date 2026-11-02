import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_info.dart';
import '../services/native_apps.dart';

class AppsController extends ChangeNotifier {
  AppsController() {
    _subscription = NativeApps.packageChanges().listen((_) => load());
  }

  StreamSubscription<String>? _subscription;

  List<AppInfo> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  SortField _sortField = SortField.name;
  bool _ascending = true;
  final Set<String> _selected = {};
  int _freeRam = 0;
  int _totalRam = 0;

  bool get loading => _loading;
  String? get error => _error;
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
    _error = null;
    notifyListeners();
    try {
      final apps = await NativeApps.listApps();
      _all = apps;
      _selected.removeWhere(
        (pkg) => !_all.any((app) => app.packageName == pkg),
      );
      await refreshMemory();
    } catch (e) {
      _error = 'Could not read the installed app list.';
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

  Future<void> uninstallSelected() async {
    final targets = _all.where((app) => _selected.contains(app.packageName));
    for (final app in targets.toList()) {
      await NativeApps.uninstall(app.packageName);
      // The system shows one confirmation dialog at a time; give it a moment.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    _selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

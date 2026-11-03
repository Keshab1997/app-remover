import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_info.dart';
import '../services/native_apps.dart';
import '../services/settings.dart';
import '../state/apps_controller.dart';
import '../widgets/app_tile.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AppsController _apps = AppsController();
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    // Where the user left off yesterday, not where the widget was written.
    initialIndex: AppSettings.systemTab.value ? 1 : 0,
  );
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  /// How many apps the bar is currently asking about, 0 when it asks nothing.
  /// The number is the arm: any change to the selection disarms it, so a
  /// "confirm" can never be left standing on top of a different list.
  int _armedCount = 0;
  Timer? _armTimer;
  static const _armWindow = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _apps.load();
    _tabs.addListener(_trackTab);
  }

  /// Follows the page the user is actually on, including the frames of a
  /// swipe, so "select all" cannot act on the tab they are leaving.
  void _trackTab() {
    final value = _tabs.animation?.value ?? _tabs.index.toDouble();
    _apps.setSystemTab(value.round() == 1);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _tabs.removeListener(_trackTab);
    _apps.dispose();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _apps,
      builder: (context, _) => Scaffold(
        appBar: _searching ? _searchAppBar() : _appBar(),
        body: _body(),
        bottomNavigationBar: _apps.selectionMode
            ? _selectionBar()
            : _memoryBar(),
      ),
    );
  }

  // -------------------------------------------------------------- app bar

  PreferredSizeWidget _appBar() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppBar(
      title: Text(
        _apps.selectionMode
            ? l10n.selectedCount(_apps.selected.length)
            : l10n.appTitle,
      ),
      leading: _apps.selectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancelSelection,
              onPressed: _apps.clearSelection,
            )
          : null,
      actions: _apps.selectionMode
          ? [
              Builder(
                builder: (context) {
                  // The count belongs in the affordance: "Select all" on a
                  // 42-app tab and on a 1-app tab used to be the same
                  // mystery meat (docs/12 P0-5).
                  final visible = _apps.currentApps;
                  return IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: l10n.selectAllInTab(
                      visible.length,
                      _apps.systemTab
                          ? l10n.tabSystemAppsLabel
                          : l10n.tabUserAppsLabel,
                    ),
                    onPressed: visible.isEmpty
                        ? null
                        : () => _apps.selectAll(visible),
                  );
                },
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.search,
                onPressed: () => setState(() => _searching = true),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refresh,
                onPressed: _apps.load,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.settings,
                onPressed: _openSettings,
              ),
            ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.6),
            ),
          ),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.tabUserApps(_apps.appsFor(system: false).length)),
              Tab(text: l10n.tabSystemApps(_apps.appsFor(system: true).length)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _searchAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          AppSettings.rememberSearch(_search.text);
          _search.clear();
          _apps.setQuery('');
          setState(() => _searching = false);
        },
      ),
      title: TextField(
        controller: _search,
        autofocus: true,
        // Filtering is live, so the keyboard's action button has nothing to
        // submit: its job is to get out of the way.
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.none,
        autofillHints: const [],
        onSubmitted: (value) {
          AppSettings.rememberSearch(value);
          FocusManager.instance.primaryFocus?.unfocus();
        },
        decoration: InputDecoration(
          hintText: l10n.searchApps,
          border: InputBorder.none,
        ),
        onChanged: _apps.setQuery,
      ),
      bottom: _searchHistoryBar(l10n),
      actions: [
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: l10n.clear,
          onPressed: () {
            _search.clear();
            _apps.setQuery('');
          },
        ),
      ],
    );
  }

  /// The last few things typed into search. Looking for the same app twice in
  /// a row is the common case, and the keyboard's own history is neither
  /// something an app can rely on nor something that leaves the device
  /// (docs/12 P2-14).
  ///
  /// Reads the notifier directly instead of listening to it: the search app bar
  /// is rebuilt on every keystroke anyway, and the one path that empties the
  /// history calls setState so the row goes with it.
  PreferredSizeWidget? _searchHistoryBar(AppLocalizations l10n) {
    final history = AppSettings.searchHistory.value;
    if (history.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.history, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final query in history)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(query),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _search.text = query;
                          _apps.setQuery(query);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.clearRecentSearches,
            onPressed: () {
              // The rebuild is what removes the row; the write is what makes
              // the removal survive a restart.
              setState(() {});
              AppSettings.clearSearchHistory();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- body

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    // Only the first load has nothing to show. A later refresh keeps the rows
    // on screen under the spinner, so the list never goes blank mid-session
    // (docs/12 P0-4).
    if (_apps.loading && _apps.installedCount == 0) {
      return const _LoadingList();
    }
    if (_apps.failure != null) {
      return _refreshable(
        _EmptyState(
          icon: Icons.error_outline,
          title: l10n.loadFailed,
          action: FilledButton.tonal(
            onPressed: _apps.load,
            child: Text(l10n.tryAgain),
          ),
        ),
      );
    }
    return TabBarView(
      controller: _tabs,
      children: [_appList(system: false), _appList(system: true)],
    );
  }

  Widget _appList({required bool system}) {
    final l10n = AppLocalizations.of(context);
    final apps = _apps.appsFor(system: system);
    if (apps.isEmpty) {
      // The copy below promises a pull; without the wrapper here it would be
      // a dead instruction exactly when there was nothing else to tap. And the
      // reason for an empty list is now a third thing: a filter can empty it.
      final byQuery = _apps.query.isNotEmpty;
      final byFilter = _apps.filter != null;
      Widget action(String label, VoidCallback onPressed) =>
          FilledButton.tonal(onPressed: onPressed, child: Text(label));
      return _refreshable(
        _EmptyState(
          icon: byFilter
              ? Icons.filter_alt_off
              : (byQuery ? Icons.search_off : Icons.apps_outlined),
          title: byFilter
              ? l10n.filtersMatchNothing
              : (byQuery ? l10n.noMatches : l10n.appsNotFound),
          subtitle: byQuery ? l10n.tryDifferentSearch : l10n.pullToRefresh,
          action: byFilter
              ? action(l10n.clearFilters, _apps.clearFilters)
              : byQuery
              ? action(l10n.clearSearch, () {
                  _search.clear();
                  _apps.setQuery('');
                })
              : action(l10n.refresh, _apps.load),
        ),
      );
    }
    return _refreshable(
      Column(
        children: [
          if (_apps.narrowing)
            Padding(
              // "No matches" tells you nothing went wrong; this tells you how
              // much did. Only while something is narrowing the list - the tab
              // labels already carry the counts otherwise.
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.appsShownOf(apps.length, _apps.installedCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          _filterChips(),
          if (!system) _offlineNote(l10n),
          Expanded(child: _list(apps)),
        ],
      ),
    );
  }

  /// A phone gets a list; 600 dp or more gets the same rows in two columns.
  /// One 48 px icon per row across a tablet width is a scroll you have to
  /// finish before you can decide anything (docs/12 P2-13).
  Widget _list(List<AppInfo> apps) {
    // A keyboard left up over a list the user is trying to read hides three
    // or four rows; the first drag closes it (docs/12 P1-8).
    const dismiss = ScrollViewKeyboardDismissBehavior.onDrag;
    if (MediaQuery.sizeOf(context).width < _twoColumnBreakpoint) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        keyboardDismissBehavior: dismiss,
        itemCount: apps.length,
        itemBuilder: (context, index) => _tile(apps[index]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      keyboardDismissBehavior: dismiss,
      itemCount: apps.length,
      // mainAxisExtent rather than a childAspectRatio: a row is as tall as its
      // three lines of text, and a ratio would stretch it taller on a wider
      // screen for no reason.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 290,
        mainAxisExtent: 96,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => _tile(apps[index]),
    );
  }

  /// Past this many selected apps the run is worth warning about: Android asks
  /// for one confirmation per package, and nobody expects 30 of them.
  static const _confirmFatigueCount = 25;

  /// Shown once. "Does this app phone home?" is the first question an
  /// uninstaller gets, and the answer is a sentence, not a policy page
  /// (docs/12 P2-14, matching docs/03).
  Widget _offlineNote(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.offlineNoteSeen,
      builder: (context, seen, _) {
        if (seen) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.worksOffline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                tooltip: l10n.dismiss,
                onPressed: AppSettings.setOfflineNoteSeen,
              ),
            ],
          ),
        );
      },
    );
  }

  static const _twoColumnBreakpoint = 600.0;

  /// A bottom sheet that spans 12 inches of tablet is a banner, not a menu:
  /// same content, centred and capped (docs/12 P2-13). Phones keep the
  /// framework defaults.
  BoxConstraints? _sheetConstraints(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < _twoColumnBreakpoint) return null;
    return BoxConstraints(maxWidth: 560, maxHeight: size.height * 0.75);
  }

  Widget _tile(AppInfo app) {
    final selecting = _apps.selectionMode;
    return AppTile(
      app: app,
      selected: _apps.selected.contains(app.packageName),
      selecting: selecting,
      // In selection mode a tap means the box; out of it, the sheet. Long-press
      // is the only way in, and it is felt.
      onTap: () =>
          selecting ? _apps.toggleSelected(app.packageName) : _showActions(app),
      onLongPress: () {
        HapticFeedback.selectionClick();
        _apps.toggleSelected(app.packageName);
      },
      onSelectedChanged: (_) => _apps.toggleSelected(app.packageName),
    );
  }

  /// Sort and filters in one row, next to the list they change. Four icons in
  /// the app bar meant two of them - sort and search - were competing with each
  /// other for a glance, while the list below had no state you could see
  /// (docs/12 P1-11).
  Widget _filterChips() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final chips = <(AppFilter, String)>[
      if (_apps.usageAvailable) (AppFilter.unused, l10n.filterUnused),
      (AppFilter.large, l10n.filterLarge),
      (AppFilter.recent, l10n.filterRecent),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Tooltip(
            message: l10n.sort,
            child: ActionChip(
              avatar: Icon(
                Icons.sort,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sortLabel(l10n)),
                  const SizedBox(width: 4),
                  Icon(
                    _apps.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                  ),
                ],
              ),
              onPressed: _showSortSheet,
            ),
          ),
          const SizedBox(width: 8),
          for (final (filter, label) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: _apps.filter == filter,
                showCheckmark: false,
                onSelected: (_) => _apps.setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }

  /// Pull-to-refresh, in every state of the list — loading UI included, so a
  /// stuck frame is never a dead end.
  Widget _refreshable(Widget child) =>
      RefreshIndicator(onRefresh: _apps.load, child: child);

  // ------------------------------------------------------------ selection

  /// The bar itself is the confirmation, so a batch costs no extra popup.
  Widget _selectionBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final count = _apps.selected.length;
    final progress = _apps.uninstallProgress;
    final running = progress != null;
    final armed = !running && _armedCount == count && count > 1;
    final body = running
        ? l10n.uninstallingProgress(progress.done + 1, progress.total)
        : armed
        ? l10n.uninstallMany(count)
        : l10n.appsAndSize(count, formatBytes(_apps.selectedSize));
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        color: scheme.surfaceContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: running ? null : _onUninstallPressed,
                  icon: Icon(
                    running
                        ? Icons.hourglass_top
                        : armed
                        ? Icons.warning_amber_rounded
                        : Icons.delete_outline,
                  ),
                  label: Text(
                    running
                        ? l10n.uninstall
                        : armed
                        ? l10n.tapAgainToUninstall
                        : l10n.uninstall,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: armed ? scheme.error : null,
                    foregroundColor: armed ? scheme.onError : null,
                  ),
                ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : progress.done / progress.total,
                  minHeight: 3,
                ),
              ),
            ] else if (armed) ...[
              const SizedBox(height: 2),
              Text(
                l10n.uninstallConfirmBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (count > _confirmFatigueCount)
                Text(
                  l10n.uninstallManyWarning(count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// One tap starts a single uninstall; a batch needs the same tap twice.
  ///
  /// This used to be a dialog on top of Android's own dialog, which made two
  /// popups for one app and N+1 for a batch. Android will not let an ordinary
  /// app skip the system confirmation, so the saving had to come from the one
  /// popup we own.
  void _onUninstallPressed() {
    final count = _apps.selected.length;
    if (count == 0) return;
    if (count > 1 && _armedCount != count) {
      setState(() => _armedCount = count);
      _armTimer?.cancel();
      _armTimer = Timer(_armWindow, () => setState(_disarm));
      return;
    }
    unawaited(_runUninstall());
  }

  void _disarm() {
    _armTimer?.cancel();
    _armTimer = null;
    _armedCount = 0;
  }

  Future<void> _runUninstall() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final summary = await _apps.uninstallSelected();
    if (mounted) setState(_disarm);
    if (summary == null) return;
    if (summary.removed == 0) {
      // Every system dialog was declined: say so instead of closing silently.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uninstallNothingRemoved)),
      );
      return;
    }
    await HapticFeedback.mediumImpact();
    final freed = formatBytes(summary.freedBytes);
    // One or many, told apart in Dart: gen-l10n cannot substitute the "#" of a
    // plural in a message that also takes another placeholder.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          summary.removed == 1
              ? l10n.uninstallSummaryOne(freed)
              : l10n.uninstallSummaryMany(freed, summary.removed),
        ),
      ),
    );
  }

  /// RAM is the one number on this screen that changes without the user asking,
  /// so the whole bar is the control. It used to carry a second refresh icon -
  /// 18 px wide, next to a 44 px row, and doing what the app bar already did -
  /// while the bar itself ignored taps (docs/12 P1-10).
  Widget _memoryBar() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final used = _apps.totalRam - _apps.freeRam;
    final fraction = _apps.totalRam > 0 ? used / _apps.totalRam : 0.0;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SafeArea(
      top: false,
      child: Material(
        color: scheme.surfaceContainer,
        child: InkWell(
          onTap: _showMemorySheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant, width: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.memory,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    // Every text in this row can be ellipsised: at 420 dp, or
                    // at a 3x font scale, the same four facts need 545 px, and
                    // a RenderFlex overflow is a crash-shaped black stripe.
                    Expanded(
                      child: Text(
                        l10n.freeMemory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        formatBytes(_apps.freeRam),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_apps.totalRam > 0) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          l10n.usedOfTotal(
                            formatBytes(used),
                            formatBytes(_apps.totalRam),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              // How full the RAM is, at a glance, without reading the numbers.
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 2,
                  color: fraction > 0.9 ? scheme.error : scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMemorySheet() async {
    final l10n = AppLocalizations.of(context);
    final used = _apps.totalRam - _apps.freeRam;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: _sheetConstraints(context),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l10n.deviceMemory,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: Text(l10n.freeMemory),
                trailing: Text(formatBytes(_apps.freeRam)),
              ),
              ListTile(
                leading: const Icon(Icons.data_usage),
                title: Text(l10n.memoryUsed),
                trailing: Text(formatBytes(used)),
              ),
              ListTile(
                leading: const Icon(Icons.sd_storage),
                title: Text(l10n.memoryTotal),
                trailing: Text(formatBytes(_apps.totalRam)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _apps.refreshMemory();
                  },
                  child: Text(l10n.refreshMemory),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- actions

  String _sortLabel(AppLocalizations l10n) => switch (_apps.sortField) {
    SortField.name => l10n.sortName,
    SortField.date => l10n.sortDate,
    SortField.size => l10n.sortSize,
  };

  Future<void> _showSortSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: _sheetConstraints(context),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in SortField.values)
                  ListTile(
                    title: Text(switch (field) {
                      SortField.name => l10n.sortByName,
                      SortField.date => l10n.sortByDate,
                      SortField.size => l10n.sortBySize,
                    }),
                    trailing: _apps.sortField == field
                        ? const Icon(Icons.check, size: 20)
                        : null,
                    onTap: () {
                      _apps.setSort(field);
                      setSheetState(() {});
                    },
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    _apps.ascending ? l10n.ascending : l10n.descending,
                  ),
                  subtitle: Text(l10n.toggleSortDirection),
                  value: _apps.ascending,
                  onChanged: (_) {
                    _apps.toggleSortOrder();
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(AppInfo app) async {
    // Tapping a row is a decision to look at something else: the keyboard
    // should already be gone by the time the sheet is over it.
    FocusManager.instance.primaryFocus?.unfocus();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // Captured before the sheet opens: once it is popped, the sheet's own
    // context can no longer find the ScaffoldMessenger.
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: _sheetConstraints(context),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: LazyAppIcon(
                    packageName: app.packageName,
                    scheme: scheme,
                  ),
                  title: Text(app.label),
                  subtitle: Text(
                    '${app.packageName}\n'
                    '${l10n.versionAndSize(app.versionName, formatBytes(app.sizeBytes))}',
                  ),
                  isThreeLine: true,
                ),
                const Divider(height: 1),
                _SizeBreakdown(packageName: app.packageName),
                ListTile(
                  leading: const Icon(Icons.launch),
                  title: Text(l10n.open),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    NativeApps.launch(app.packageName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.appInfo),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    NativeApps.openAppInfo(app.packageName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(l10n.searchInPlay),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    NativeApps.openPlayStore(app.packageName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_to_home_screen_outlined),
                  title: Text(l10n.addToHomeScreen),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final ok = await NativeApps.addShortcut(app.packageName);
                    // `context` is the State's own, so the State's mounted flag
                    // is the guard the analyzer (and reality) wants.
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        // false covers both "launcher cannot pin" and "this app
                        // has no launch intent", which the user cannot act on.
                        content: Text(
                          ok
                              ? l10n.shortcutRequested
                              : l10n.shortcutUnsupported,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  // The one string you actually want off this screen, and a
                  // Text inside a sheet cannot be selected (docs/12 P2-14).
                  leading: const Icon(Icons.copy_all_outlined),
                  title: Text(l10n.copyPackageName),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: app.packageName));
                    Navigator.pop(sheetContext);
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard)),
                    );
                  },
                ),
                ListTile(
                  enabled: !app.isSystem,
                  leading: Icon(
                    Icons.delete_outline,
                    color: app.isSystem ? null : scheme.error,
                  ),
                  title: Text(
                    app.isSystem ? l10n.systemAppsProtected : l10n.uninstall,
                    style: app.isSystem ? null : TextStyle(color: scheme.error),
                  ),
                  onTap: app.isSystem
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          if (await _apps.uninstall(app)) {
                            await HapticFeedback.mediumImpact();
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}

/// Rows in the shape of the real list while the first `listApps` is in flight.
///
/// A centred spinner says "something is happening"; a skeleton says how many
/// things and where they will land, so the first frame is never an empty pane.
/// The pulse is one AnimationController - a shimmer package is a lot of
/// dependency to dress up eight grey rectangles.
class _LoadingList extends StatefulWidget {
  const _LoadingList();

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// Started from didChangeDependencies, not initState: reading MediaQuery
  /// before the first build is an assertion, and it has to be re-read anyway
  /// if the user flips "reduce motion" while the app is open.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pulse.stop();
      _pulse.value = 0.7;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          // Fake rows hold no information: keep them out of the a11y tree and
          // out of the way of a real gesture.
          child: ExcludeSemantics(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              itemBuilder: (context, index) => _SkeletonTile(
                index: index,
                color: scheme.surfaceContainerHighest,
                animation: _pulse,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.loadingApps,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// One grey row: the same metrics as [AppTile], so nothing shifts when the
/// real rows replace it.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({
    required this.index,
    required this.color,
    required this.animation,
  });

  final int index;
  final Color color;
  final Animation<double> animation;

  static const _titleWidths = [0.55, 0.42, 0.63, 0.38, 0.50, 0.60, 0.45, 0.35];
  static const _subWidths = [0.32, 0.44, 0.28, 0.40, 0.36, 0.30, 0.42, 0.26];

  @override
  Widget build(BuildContext context) {
    final slot = index % _titleWidths.length;
    final width = MediaQuery.sizeOf(context).width;
    // Rows breathe out of step with each other, which reads as progress;
    // Interval keeps that inside the one shared controller.
    final begin = index * 0.03;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, begin + 0.78),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.85).animate(curved),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              _SkeletonBlock(size: 48, radius: 12, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(
                      width: width * _titleWidths[slot],
                      height: 14,
                      radius: 4,
                      color: color,
                    ),
                    const SizedBox(height: 6),
                    _SkeletonBlock(
                      width: width * _subWidths[slot],
                      height: 10,
                      radius: 4,
                      color: color,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SkeletonBlock(size: 24, radius: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.size,
    this.width,
    this.height,
    required this.radius,
    required this.color,
  }) : assert(size != null || (width != null && height != null));

  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size ?? width,
      height: size ?? height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// App / data / cache bytes for one package, asked for when the sheet opens.
///
/// `listApps` deliberately reports only the APK size (querying 200 packages
/// costs a second), so the exact numbers are fetched for the one app the user
/// actually tapped (docs/08).
class _SizeBreakdown extends StatefulWidget {
  const _SizeBreakdown({required this.packageName});

  final String packageName;

  @override
  State<_SizeBreakdown> createState() => _SizeBreakdownState();
}

class _SizeBreakdownState extends State<_SizeBreakdown> {
  late final Future<_Sizes> _sizes = _load();

  Future<_Sizes> _load() async {
    // No storage stats live behind a browser, and the channel is not there to
    // ask; say nothing rather than invite the user to a settings page that
    // does not exist.
    if (kIsWeb) return const _Sizes();
    final breakdown = await NativeApps.sizeBreakdown(widget.packageName);
    if (breakdown != null) return _Sizes(breakdown: breakdown);
    // A granted-but-failed query (package gone mid-tap) is transient, so it
    // must not nag about a permission the user already gave.
    if (await NativeApps.hasUsageAccess()) return const _Sizes();
    return const _Sizes(needsAccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_Sizes>(
      future: _sizes,
      builder: (context, snapshot) {
        final sizes = snapshot.data;
        if (sizes == null) return const SizedBox(height: 6);
        final breakdown = sizes.breakdown;
        if (breakdown != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SizeCell(
                  label: l10n.sizeApp,
                  bytes: breakdown.app,
                  theme: theme,
                ),
                _SizeCell(
                  label: l10n.sizeData,
                  bytes: breakdown.data,
                  theme: theme,
                ),
                _SizeCell(
                  label: l10n.sizeCache,
                  bytes: breakdown.cache,
                  theme: theme,
                ),
              ],
            ),
          );
        }
        if (!sizes.needsAccess) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: AppSettings.sizesHint,
          builder: (context, showHint, _) {
            if (!showHint) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sizesHintTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: NativeApps.openUsageAccessSettings,
                    child: Text(l10n.enable),
                  ),
                  IconButton(
                    tooltip: l10n.noThanks,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    onPressed: () => AppSettings.setSizesHint(false),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// What the sheet can say about one package's storage.
class _Sizes {
  const _Sizes({this.breakdown, this.needsAccess = false});

  final ({int app, int data, int cache, int total})? breakdown;
  final bool needsAccess;
}

class _SizeCell extends StatelessWidget {
  const _SizeCell({
    required this.label,
    required this.bytes,
    required this.theme,
  });

  final String label;
  final int bytes;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatBytes(bytes),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

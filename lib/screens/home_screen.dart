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
                icon: const Icon(Icons.sort),
                tooltip: l10n.sort,
                onPressed: _showSortSheet,
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
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: l10n.searchApps,
          border: InputBorder.none,
        ),
        onChanged: _apps.setQuery,
      ),
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              // A keyboard left up over a list the user is trying to read hides
              // three or four rows; the first drag closes it (docs/12 P1-8).
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final selecting = _apps.selectionMode;
                return AppTile(
                  app: app,
                  selected: _apps.selected.contains(app.packageName),
                  selecting: selecting,
                  // In selection mode a tap means the box; out of it, the
                  // sheet. Long-press is the only way in, and it is felt.
                  onTap: () => selecting
                      ? _apps.toggleSelected(app.packageName)
                      : _showActions(app),
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    _apps.toggleSelected(app.packageName);
                  },
                  onSelectedChanged: (_) =>
                      _apps.toggleSelected(app.packageName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// One reason to uninstall, one tap away. A chip the device cannot answer is
  /// not shown at all: a greyed-out "not used in 90 days" waiting on a
  /// permission the user has not granted is an ad, not a filter
  /// (docs/12 P1-7).
  Widget _filterChips() {
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

  Widget _selectionBar() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        color: scheme.surfaceContainer,
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.appsAndSize(
                  _apps.selected.length,
                  formatBytes(_apps.selectedSize),
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _confirmUninstallSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.uninstall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memoryBar() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final used = _apps.totalRam - _apps.freeRam;
    return SafeArea(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.memory, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              l10n.freeMemory,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              formatBytes(_apps.freeRam),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_apps.totalRam > 0)
              Text(
                l10n.usedOfTotal(
                  formatBytes(used),
                  formatBytes(_apps.totalRam),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refreshMemory,
              onPressed: _apps.refreshMemory,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- actions

  Future<void> _showSortSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
                title: Text(_apps.ascending ? l10n.ascending : l10n.descending),
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
    );
  }

  Future<void> _showActions(AppInfo app) async {
    // Tapping a row is a decision to look at something else: the keyboard
    // should already be gone by the time the sheet is over it.
    FocusManager.instance.primaryFocus?.unfocus();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
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
                        ok ? l10n.shortcutRequested : l10n.shortcutUnsupported,
                      ),
                    ),
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
        );
      },
    );
  }

  /// Asks once, then reports each system dialog as it comes.
  ///
  /// The dialog stays open and refills itself while the run is going: the user
  /// has to answer one confirmation per app, so it is the only place that can
  /// say how many are left (docs/12 P0-3).
  Future<void> _confirmUninstallSelected() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = _apps.selected.length;
    final summary = await showDialog<UninstallSummary>(
      context: context,
      // Tapping out mid-run would leave the remaining dialogs unexplained.
      barrierDismissible: false,
      builder: (dialogContext) => AnimatedBuilder(
        animation: _apps,
        builder: (context, _) {
          final progress = _apps.uninstallProgress;
          final running = progress != null;
          return AlertDialog(
            title: Text(
              count == 1 ? l10n.uninstallOne : l10n.uninstallMany(count),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.appsAndSize(count, formatBytes(_apps.selectedSize))}\n'
                  '${l10n.uninstallConfirmBody}',
                ),
                if (running) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.total == 0
                          ? null
                          : progress.done / progress.total,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.uninstallingProgress(
                      progress.done + 1,
                      progress.total,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            actions: [
              if (!running)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
              FilledButton(
                onPressed: running
                    ? null
                    : () async {
                        final result = await _apps.uninstallSelected();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, result);
                        }
                      },
                child: Text(l10n.uninstall),
              ),
            ],
          );
        },
      ),
    );
    if (summary == null) return;
    if (summary.removed == 0) {
      // Nothing left the device - every dialog was declined. Say so instead of
      // closing silently.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uninstallNothingRemoved)),
      );
      return;
    }
    await HapticFeedback.mediumImpact();
    // One or many, told apart in Dart: gen-l10n cannot substitute the "#" of a
    // plural in a message that also takes another placeholder, so the two forms
    // cannot share one ICU plural here.
    final freed = formatBytes(summary.freedBytes);
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

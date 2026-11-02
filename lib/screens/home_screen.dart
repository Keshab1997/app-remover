import 'package:flutter/material.dart';

import '../models/app_info.dart';
import '../services/native_apps.dart';
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
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _apps.load();
  }

  @override
  void dispose() {
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
    return AppBar(
      title: Text(
        _apps.selectionMode
            ? '${_apps.selected.length} selected'
            : 'Goodbye Apps',
      ),
      leading: _apps.selectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: _apps.clearSelection,
            )
          : null,
      actions: _apps.selectionMode
          ? [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Select all',
                onPressed: () =>
                    _apps.selectAll(_apps.appsFor(system: _tabs.index == 1)),
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () => setState(() => _searching = true),
              ),
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onPressed: _showSortSheet,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _apps.load,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
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
              Tab(text: 'User apps (${_apps.appsFor(system: false).length})'),
              Tab(text: 'System apps (${_apps.appsFor(system: true).length})'),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _searchAppBar() {
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
        decoration: const InputDecoration(
          hintText: 'Search apps',
          border: InputBorder.none,
        ),
        onChanged: _apps.setQuery,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
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
    if (_apps.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading apps…'),
          ],
        ),
      );
    }
    if (_apps.error != null) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: _apps.error!,
        action: FilledButton.tonal(
          onPressed: _apps.load,
          child: const Text('Try again'),
        ),
      );
    }
    return TabBarView(
      controller: _tabs,
      children: [_appList(system: false), _appList(system: true)],
    );
  }

  Widget _appList({required bool system}) {
    final apps = _apps.appsFor(system: system);
    if (apps.isEmpty) {
      return _EmptyState(
        icon: Icons.apps_outlined,
        title: _apps.query.isEmpty ? 'Apps not found' : 'No matches',
        subtitle: _apps.query.isEmpty
            ? 'Pull down to refresh the list.'
            : 'Try a different name or package.',
      );
    }
    return RefreshIndicator(
      onRefresh: _apps.load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          return AppTile(
            app: app,
            selected: _apps.selected.contains(app.packageName),
            onTap: () => _showActions(app),
            onLongPress: () => _apps.toggleSelected(app.packageName),
            onSelectedChanged: (_) => _apps.toggleSelected(app.packageName),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ selection

  Widget _selectionBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        color: scheme.surfaceContainer,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_apps.selected.length} apps • '
                '${formatBytes(_apps.selectedSize)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _confirmUninstallSelected,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Uninstall'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memoryBar() {
    final theme = Theme.of(context);
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
              'Free memory',
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
                '${formatBytes(used)} / ${formatBytes(_apps.totalRam)} used',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh memory',
              onPressed: _apps.refreshMemory,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- actions

  Future<void> _showSortSheet() async {
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
                  title: Text('Sort by ${field.label.toLowerCase()}'),
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
                title: Text(_apps.ascending ? 'Ascending' : 'Descending'),
                subtitle: const Text('Toggle sort direction'),
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
    final scheme = Theme.of(context).colorScheme;
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
                  'v${app.versionName} • ${formatBytes(app.sizeBytes)}',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              _SizeBreakdown(packageName: app.packageName),
              ListTile(
                leading: const Icon(Icons.launch),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  NativeApps.launch(app.packageName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App info'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  NativeApps.openAppInfo(app.packageName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Search in Google Play'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  NativeApps.openPlayStore(app.packageName);
                },
              ),
              ListTile(
                enabled: !app.isSystem,
                leading: Icon(
                  Icons.delete_outline,
                  color: app.isSystem ? null : scheme.error,
                ),
                title: Text(
                  app.isSystem
                      ? "System apps can't be uninstalled"
                      : 'Uninstall',
                  style: app.isSystem ? null : TextStyle(color: scheme.error),
                ),
                onTap: app.isSystem
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await _apps.uninstall(app);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmUninstallSelected() async {
    final count = _apps.selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Uninstall app?' : 'Uninstall $count apps?'),
        content: Text(
          '$count apps • ${formatBytes(_apps.selectedSize)}\n'
          'The system will ask you to confirm each uninstall.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apps.uninstallSelected();
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}

/// App / data / cache bytes for one package, asked for when the sheet opens.
///
/// `listApps` deliberately reports only the APK size (querying 200 packages
/// costs a second), so the exact numbers are fetched for the one app the user
/// actually tapped (docs/08). Without usage access this renders nothing.
class _SizeBreakdown extends StatelessWidget {
  const _SizeBreakdown({required this.packageName});

  final String packageName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<({int app, int data, int cache, int total})?>(
      future: NativeApps.sizeBreakdown(packageName),
      builder: (context, snapshot) {
        final breakdown = snapshot.data;
        if (breakdown == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SizeCell(label: 'App', bytes: breakdown.app, theme: theme),
              _SizeCell(label: 'Data', bytes: breakdown.data, theme: theme),
              _SizeCell(label: 'Cache', bytes: breakdown.cache, theme: theme),
            ],
          ),
        );
      },
    );
  }
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

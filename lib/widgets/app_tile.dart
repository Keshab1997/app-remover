import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_info.dart';
import '../services/icon_store.dart';

class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.app,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectedChanged,
  });

  final AppInfo app;
  final bool selected;

  /// Whether the list is in selection mode. Out of it there is no box to
  /// tick - the row is either a thing to open or a thing to remove, and an
  /// always-on Checkbox made every row ask which of the two it was
  /// (docs/12 P1-9).
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              LazyAppIcon(packageName: app.packageName, scheme: scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatBytes(app.sizeBytes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Dot(color: scheme.outline),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _changed(l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selecting)
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelectedChanged(value ?? false),
                  shape: const CircleBorder(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The date slot answers "so what". Opened yesterday tells the user nothing
  /// about whether to remove an app; untouched for a season tells them
  /// everything, so the stale end of the list says so out loud (docs/12 P1-7).
  String _changed(AppLocalizations l10n) {
    final lastUsed = app.lastUsedAt;
    if (lastUsed != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(lastUsed);
      if (DateTime.now().difference(at) > _staleAfter) {
        return l10n.notOpenedSince(formatDate(at));
      }
    }
    return formatDate(app.changedAt);
  }
}

/// Below this, "last opened" is not a signal worth a line of the row.
const _staleAfter = Duration(days: 30);

/// One row's icon: asks [IconStore] on first build and repaints itself when
/// the bytes land. Deliberately its own widget, so an icon arriving repaints
/// 48 px instead of the whole list.

class LazyAppIcon extends StatefulWidget {
  const LazyAppIcon({
    super.key,
    required this.packageName,
    required this.scheme,
    this.store,
  });

  final String packageName;
  final ColorScheme scheme;

  /// Overridable so a test can hand one tile an isolated cache.
  final IconStore? store;

  @override
  State<LazyAppIcon> createState() => _LazyAppIconState();
}

class _LazyAppIconState extends State<LazyAppIcon> {
  IconStore get _store => widget.store ?? IconStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onIconsChanged);
    _store.request(widget.packageName);
  }

  @override
  void didUpdateWidget(LazyAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName == widget.packageName) return;
    _store.request(widget.packageName);
    setState(() {});
  }

  void _onIconsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onIconsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppIcon(icon: _store[widget.packageName], scheme: widget.scheme);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.icon, required this.scheme});

  final Uint8List? icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 48, height: 48, child: _content()),
    );
  }

  Widget _content() {
    final bytes = icon;
    if (bytes == null || bytes.isEmpty) return _fallback();
    return Image.memory(
      bytes,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.android, color: scheme.onSurfaceVariant, size: 26),
    );
  }
}

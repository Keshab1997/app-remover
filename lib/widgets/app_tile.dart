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
              // Decorative: the label is right next to it, and TalkBack would
              // otherwise read "android, icon" before every app name.
              ExcludeSemantics(
                child: LazyAppIcon(
                  packageName: app.packageName,
                  scheme: scheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (app.installedRecently()) ...[
                          const SizedBox(width: 8),
                          // Flexible, not fixed: on a narrow grid cell the
                          // name next to it has to survive the badge.
                          Flexible(
                            child: _RecentBadge(label: l10n.filterRecent),
                          ),
                        ],
                      ],
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
                        // Both halves of the meta line give way to the other:
                        // in a 290 px grid tile the pair does not fit at a
                        // readable size, and an overflow stripe across a row is
                        // worse than an ellipsis (docs/12 P2-13, P2-12).
                        Flexible(
                          child: Text(
                            formatBytes(app.sizeBytes),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
                            style: theme.textTheme.bodySmall?.copyWith(
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
                // "Checkbox, unchecked" tells a screen-reader user nothing
                // about which app they are about to remove; the name has to
                // travel with the control (docs/12 P2-12).
                Semantics(
                  selected: selected,
                  label: app.label,
                  child: Checkbox(
                    value: selected,
                    onChanged: (value) => onSelectedChanged(value ?? false),
                    shape: const CircleBorder(),
                  ),
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

/// The one thing on this row that needs no reading: it is new.
class _RecentBadge extends StatelessWidget {
  const _RecentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      // Capped and ellipsised: the name beside it matters more than the badge,
      // and a translation can be twice as long as the English.
      constraints: const BoxConstraints(maxWidth: 140),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
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
      child: SizedBox(width: 48, height: 48, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    final bytes = icon;
    if (bytes == null || bytes.isEmpty) return _fallback();
    final image = Image.memory(
      bytes,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
    );
    // Icons land row by row as IconStore fills its cache, so each one cross-
    // fades from the placeholder instead of popping in (docs/12 P2-14) - and
    // does not fade at all when the system says not to animate.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return image;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: image,
    );
  }

  Widget _fallback() {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.android, color: scheme.onSurfaceVariant, size: 26),
    );
  }
}

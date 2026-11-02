import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/app_info.dart';

class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.app,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectedChanged,
  });

  final AppInfo app;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              AppIcon(icon: app.icon, scheme: scheme),
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
                        Text(
                          formatDate(app.changedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

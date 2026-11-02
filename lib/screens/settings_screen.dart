import 'package:flutter/material.dart';

import '../services/native_apps.dart';
import '../services/settings.dart';

const String appPackageId = 'com.keshabstudios.goodbyeapps';

// TODO: host these on goodbyeapps.com before publishing (or point them at an
// existing privacy policy / support inbox).
const String privacyPolicyUrl = 'https://goodbyeapps.com/privacy-policy';
const String supportEmail = 'hello@goodbyeapps.com';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<({String name, int code})> _version =
      NativeApps.appVersion();

  late Future<bool> _usageAccess = NativeApps.hasUsageAccess();

  /// Re-read on every tap: usage access is granted on a settings screen the
  /// app cannot observe, so this is the cheapest honest refresh.
  Future<void> _refreshUsageAccess() async {
    setState(() => _usageAccess = NativeApps.hasUsageAccess());
    await _usageAccess;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Appearance'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.themeMode,
            builder: (context, mode, _) => ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Theme'),
              subtitle: Text(switch (mode) {
                ThemeMode.system => 'System default',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              }),
              onTap: () => _pickTheme(mode),
            ),
          ),
          const Divider(),
          _SectionHeader('Storage'),
          FutureBuilder<bool>(
            future: _usageAccess,
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Detailed app sizes'),
              subtitle: Text(
                snapshot.data ?? false
                    ? 'Usage access is on — sheets show app, data and cache'
                    : 'Turn on usage access to see data and cache size',
              ),
              trailing: snapshot.data ?? false
                  ? const Icon(Icons.check, size: 20)
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                if (await NativeApps.hasUsageAccess()) {
                  await _refreshUsageAccess();
                  return;
                }
                await NativeApps.openUsageAccessSettings();
              },
            ),
          ),
          const Divider(),
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('Rate this app'),
            subtitle: const Text('Give us 5 stars on Google Play'),
            onTap: () =>
                NativeApps.openUrl('market://details?id=$appPackageId'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share app'),
            onTap: () => NativeApps.share(
              'Check out Goodbye Apps – a simple way to uninstall apps.\n'
              'https://play.google.com/store/apps/details?id=$appPackageId',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Send feedback'),
            onTap: () => NativeApps.openUrl(
              'mailto:$supportEmail?subject=Goodbye%20Apps%20feedback',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => NativeApps.openUrl(privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: FutureBuilder<({String name, int code})>(
              future: _version,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('…');
                final v = snapshot.data!;
                return Text('${v.name} (${v.code})');
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Goodbye Apps',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              (ThemeMode.system, 'System default'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
            ])
              ListTile(
                title: Text(option.$2),
                trailing: option.$1 == current
                    ? const Icon(Icons.check, size: 20)
                    : null,
                onTap: () => Navigator.pop(sheetContext, option.$1),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await AppSettings.setThemeMode(chosen);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

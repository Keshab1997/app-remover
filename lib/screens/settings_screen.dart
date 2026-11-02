import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(l10n.sectionAppearance),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.themeMode,
            builder: (context, mode, _) => ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(l10n.theme),
              subtitle: Text(switch (mode) {
                ThemeMode.system => l10n.systemDefault,
                ThemeMode.light => l10n.light,
                ThemeMode.dark => l10n.dark,
              }),
              onTap: () => _pickTheme(mode),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.sectionStatusBar),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.statusBar,
            builder: (context, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.statusBarToggle),
              subtitle: Text(enabled ? l10n.statusBarOn : l10n.statusBarOff),
              value: enabled,
              onChanged: _setStatus,
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.sectionStorage),
          FutureBuilder<bool>(
            future: _usageAccess,
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(l10n.detailedAppSizes),
              subtitle: Text(
                snapshot.data ?? false
                    ? l10n.usageAccessOn
                    : l10n.usageAccessOff,
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
          _SectionHeader(l10n.sectionAbout),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: Text(l10n.rateApp),
            subtitle: Text(l10n.rateSubtitle),
            onTap: () =>
                NativeApps.openUrl('market://details?id=$appPackageId'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.shareApp),
            onTap: () => NativeApps.share(
              l10n.shareBody(
                'https://play.google.com/store/apps/details?id=$appPackageId',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.sendFeedback),
            onTap: () => NativeApps.openUrl(
              'mailto:$supportEmail?subject=Goodbye%20Apps%20feedback',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            onTap: () => NativeApps.openUrl(privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
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
              l10n.appTitle,
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

  /// Turns the tray notification on or off, and explains itself when Android
  /// says no — the permission dialog can be answered once and forever.
  Future<void> _setStatus(bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final granted = await NativeApps.setStatusBarNotification(enabled);
    if (!mounted) return;
    if (!granted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.notificationsOffTitle),
          content: Text(l10n.notificationsOffBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // openUrl only takes http/https; this page is an intent.
                NativeApps.openNotificationSettings();
              },
              child: Text(l10n.openSettings),
            ),
          ],
        ),
      );
      return;
    }
    await AppSettings.setStatusBar(enabled);
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final options = [
          (ThemeMode.system, l10n.systemDefault),
          (ThemeMode.light, l10n.light),
          (ThemeMode.dark, l10n.dark),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  title: Text(option.$2),
                  trailing: option.$1 == current
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option.$1),
                ),
            ],
          ),
        );
      },
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

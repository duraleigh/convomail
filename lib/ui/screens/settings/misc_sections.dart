import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_log.dart';
import '../../../app/settings.dart';
import '../../../app/update_check.dart';
import '../../../app/version.dart';
import '../../../platform/mailto_registration.dart';
import '../../../platform/windows_integration.dart';
import '../../../sync/notification_center.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import 'accounts_section.dart' show accountsStreamProvider;

/// Settings → Notifications (spec 4.17, 4.18): the global switch, badge
/// scope (People only by default), and per-account mute. Toast delivery
/// itself arrives with the Windows integration milestone; these settings
/// are what it will read.
class NotificationsDetail extends ConsumerWidget {
  const NotificationsDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountsStreamProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = ref.read(settingsProvider.notifier);
    return ListView(
      children: [
        GroupedList(
          children: [
            SwitchListTile(
              key: const ValueKey('notifications-enabled'),
              secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
              title: const Text('Notify me about new mail'),
              subtitle: const Text('Windows toast notifications for messages from People.'),
              value: settings.notificationsEnabled,
              onChanged: n.setNotificationsEnabled,
            ),
            SwitchListTile(
              key: const ValueKey('badge-include-feeds'),
              secondary: Icon(Icons.rss_feed_rounded, color: scheme.primary),
              title: const Text('Feeds count toward the badge'),
              subtitle: const Text('Off: the unread badge counts People only. Individual Feeds senders can still opt in from their row.'),
              value: settings.badgeIncludeFeeds,
              onChanged: n.setBadgeIncludeFeeds,
            ),
          ],
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          Text('Per account', style: text.labelSmall!.copyWith(letterSpacing: 1)),
          const SizedBox(height: AppSpace.sm),
          GroupedList(
            children: [
              for (final a in accounts)
                SwitchListTile(
                  key: ValueKey('notify-account-${a.id}'),
                  title: Text(a.email),
                  subtitle: Text(settings.mutedAccounts.contains(a.id) ? 'Muted' : 'Notifications on'),
                  value: !settings.mutedAccounts.contains(a.id),
                  onChanged: (on) => n.setAccountMuted(a.id, !on),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        Text('Windows', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: AppSpace.sm),
        GroupedList(
          children: [
            SwitchListTile(
              key: const ValueKey('show-badge'),
              secondary: Icon(Icons.filter_9_plus_outlined, color: scheme.primary),
              title: const Text('Unread count on the taskbar icon'),
              subtitle: const Text('Off hides the badge entirely.'),
              value: settings.showBadge,
              onChanged: n.setShowBadge,
            ),
            SwitchListTile(
              key: const ValueKey('close-to-tray'),
              secondary: Icon(Icons.minimize_rounded, color: scheme.primary),
              title: const Text('Keep running in the tray when the window is closed'),
              subtitle: const Text('Mail keeps syncing and notifications keep arriving. Quit from the tray icon.'),
              value: settings.closeToTray,
              onChanged: n.setCloseToTray,
            ),
            SwitchListTile(
              key: const ValueKey('launch-at-login'),
              secondary: Icon(Icons.power_settings_new_rounded, color: scheme.primary),
              title: const Text('Start with Windows'),
              subtitle: const Text('Starts minimized to the tray when you sign in.'),
              value: settings.launchAtLogin,
              onChanged: n.setLaunchAtLogin,
            ),
            ListTile(
              leading: Icon(Icons.notification_add_outlined, color: scheme.primary),
              title: const Text('Send a test notification'),
              onTap: () => ref.read(notificationSinkProvider).show(OutgoingNotification(id: 'test:${DateTime.now().millisecondsSinceEpoch}', title: 'ConvoMail', body: 'Notifications are working.')),
            ),
          ],
        ),
        if (ref.watch(windowsIntegrationProvider) == null) ...[
          const SizedBox(height: AppSpace.sm),
          Text('Tray, badge, and toasts are active in the Windows build.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Settings → Default mail app (spec 4.18): register the `mailto:` handler
/// for this user and jump to the Windows page where the default is chosen.
class DefaultAppDetail extends ConsumerStatefulWidget {
  const DefaultAppDetail({super.key});

  @override
  ConsumerState<DefaultAppDetail> createState() => _DefaultAppDetailState();
}

class _DefaultAppDetailState extends ConsumerState<DefaultAppDetail> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final reg = ref.watch(mailtoRegistrationProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final registered = reg.isRegistered;
    return ListView(
      children: [
        GroupedList(
          children: [
            ListTile(
              leading: Icon(registered ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded, color: registered ? scheme.primary : scheme.onSurfaceVariant),
              title: Text(registered ? 'Registered as an email handler' : 'Not registered yet'),
              subtitle: Text(registered
                  ? 'ConvoMail appears under Windows Settings → Apps → Default apps → Email. Links such as mailto: open the composer once you pick it there.'
                  : 'Registering adds ConvoMail to the list Windows offers for email links. Nothing changes until you choose it there.'),
              trailing: FilledButton.tonal(
                key: const ValueKey('mailto-register'),
                onPressed: () {
                  setState(() => _error = null);
                  try {
                    registered ? reg.unregister() : reg.register();
                  } catch (e) {
                    _error = 'Could not update the registry: $e';
                  }
                  setState(() {});
                },
                child: Text(registered ? 'Unregister' : 'Register'),
              ),
            ),
            ListTile(
              leading: Icon(Icons.open_in_new_rounded, color: scheme.primary),
              title: const Text('Open Windows default apps'),
              subtitle: const Text('Choose ConvoMail under Email.'),
              onTap: () => launchUrl(Uri.parse('ms-settings:defaultapps')),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(_error!, style: text.bodyMedium!.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: AppSpace.lg),
        Text('The registration is per user and writes only under HKEY_CURRENT_USER. Launching from a link while the app is already open is handled in milestone 10 (single instance).', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}


/// Settings → About & updates (plan M12): version, manual update check
/// against a user-supplied feed, and the local diagnostics log.
class AboutDetail extends ConsumerStatefulWidget {
  const AboutDetail({super.key});

  @override
  ConsumerState<AboutDetail> createState() => _AboutDetailState();
}

class _AboutDetailState extends ConsumerState<AboutDetail> {
  late final TextEditingController _feed;
  UpdateResult? _result;
  bool _checking = false;
  int? _logBytes;

  @override
  void initState() {
    super.initState();
    _feed = TextEditingController(text: ref.read(settingsProvider).updateFeedUrl);
    _refreshLogSize();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  Future<void> _refreshLogSize() async {
    final log = ref.read(appLogProvider);
    final n = log == null ? 0 : await log.totalBytes();
    if (mounted) setState(() => _logBytes = n);
  }

  Future<void> _check() async {
    final url = _feed.text.trim();
    await ref.read(settingsProvider.notifier).setUpdateFeedUrl(url);
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme) {
      setState(() => _result = const UpdateCheckFailed('Enter the https address of an update feed first.'));
      return;
    }
    setState(() => _checking = true);
    final r = await ref.read(updateCheckerProvider).check(uri);
    if (mounted) {
      setState(() {
        _checking = false;
        _result = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final log = ref.watch(appLogProvider);
    final result = _result;
    return ListView(
      children: [
        GroupedList(
          children: [
            ListTile(
              leading: Icon(Icons.forum_rounded, color: scheme.primary),
              title: const Text('ConvoMail'),
              subtitle: const Text('Version $appVersion (build $appBuild) · Windows'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Text('UPDATES', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: AppSpace.sm),
        GroupedList(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: TextField(
                key: const ValueKey('update-feed'),
                controller: _feed,
                decoration: const InputDecoration(labelText: 'Update feed (https)', hintText: 'https://example.com/convomail/latest.json', border: OutlineInputBorder()),
                onSubmitted: (_) => _check(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('check-updates'),
                    onPressed: _checking ? null : _check,
                    icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.system_update_alt_rounded),
                    label: const Text('Check for updates'),
                  ),
                  const SizedBox(width: AppSpace.md),
                  if (result != null)
                    Expanded(
                      child: switch (result) {
                        UpToDate(:final current) => Text('You have the latest version ($current).', style: text.bodyMedium),
                        UpdateCheckFailed(:final message) => Text(message, style: text.bodyMedium!.copyWith(color: scheme.error)),
                        UpdateAvailable(:final info) => Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpace.sm,
                            children: [
                              Text('Version ${info.version} is available.', style: text.bodyMedium),
                              TextButton(onPressed: () => launchUrl(Uri.parse(info.url)), child: const Text('Download')),
                            ],
                          ),
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text('There is no automatic download or telemetry. The feed is a small JSON file with "version", "url" and optional "notes". Nothing is checked until you press the button.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpace.xl),
        Text('DIAGNOSTICS', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: AppSpace.sm),
        GroupedList(
          children: [
            ListTile(
              leading: Icon(Icons.bug_report_outlined, color: scheme.primary),
              title: const Text('Local error log'),
              subtitle: Text(log == null ? 'Not available in this build.' : '${log.dir.path}\n${_sizeLabel(_logBytes)} · kept ${log.keepDays} days · exceptions and stack traces only, never message content'),
              isThreeLine: log != null,
            ),
            if (log != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await log.dir.create(recursive: true);
                        await Process.start('explorer.exe', [log.dir.path], mode: ProcessStartMode.detached);
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Open log folder'),
                    ),
                    const SizedBox(width: AppSpace.md),
                    TextButton.icon(
                      onPressed: () async {
                        await log.clear();
                        await _refreshLogSize();
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Clear logs'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _sizeLabel(int? bytes) {
    if (bytes == null) return '…';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

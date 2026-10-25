import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/settings.dart';
import '../../../platform/mailto_registration.dart';
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
        const SizedBox(height: AppSpace.lg),
        Text('Delivery of toasts, the taskbar badge, and tray icon arrive in milestone 10.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
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

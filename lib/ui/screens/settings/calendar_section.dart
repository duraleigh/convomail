import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/calendar_state.dart';
import '../../../app/settings_navigation.dart';
import '../../../sync/calendar_sync.dart';
import '../../../sync/contacts_sync.dart';
import '../../widgets/grouped_list.dart';

/// Settings → Google Calendar: the Planner shows the calendars the user
/// shows in Google, and events made or changed in the Planner go there.
class GoogleCalendarDetail extends ConsumerStatefulWidget {
  const GoogleCalendarDetail({super.key});

  @override
  ConsumerState<GoogleCalendarDetail> createState() => _GoogleCalendarDetailState();
}

class _GoogleCalendarDetailState extends ConsumerState<GoogleCalendarDetail> {
  bool _loading = true;
  bool _connected = false;
  bool _hasCalendar = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final oauth = ref.read(googleOAuthProvider);
    final connected = await oauth.isConnected;
    final hasCalendar = connected && await oauth.hasCalendar;
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _hasCalendar = hasCalendar;
      _loading = false;
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  /// Signs in again asking for the calendar as well as contacts.
  Future<void> _allow() => _run(() async {
        await ref.read(googleOAuthProvider).connect();
        final sync = ref.read(calendarSyncProvider);
        await sync.syncNow();
        sync.start();
      });

  Future<void> _syncNow() => _run(() => ref.read(calendarSyncProvider).syncNow());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    if (_loading) return const SizedBox.shrink();
    final calendars = ref.watch(googleCalendarsProvider).value ?? const <GoogleCalendarInfo>[];
    final hidden = ref.watch(hiddenCalendarsProvider).value ?? const <String>{};
    final defaultId = ref.watch(defaultCalendarIdProvider).value;
    final lastSync = ref.watch(calendarLastSyncProvider).value;
    final syncError = ref.watch(calendarErrorProvider).value;
    final error = _error ?? syncError;
    final writable = [for (final c in calendars) if (c.writable) c];

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'The Planner shows every calendar you show in Google Calendar, in its colours. Events you add, change or delete in the Planner are added, changed or deleted in Google Calendar too.',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        GroupedList(
          children: [
            if (!_connected)
              ListTile(
                key: const ValueKey('calendar-needs-google'),
                leading: const Icon(Icons.link_rounded),
                title: const Text('Connect Google first'),
                subtitle: const Text('Calendar uses the same Google connection as Contacts: your OAuth client file, then Connect.'),
                trailing: TextButton(onPressed: () => ref.read(settingsSectionProvider.notifier).select(SettingsSection.contacts), child: const Text('Open Google Contacts')),
              )
            else if (!_hasCalendar)
              ListTile(
                key: const ValueKey('calendar-allow'),
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('Allow calendar access'),
                subtitle: const Text('Opens your browser to sign in to Google again, this time also allowing the calendar. Turn on the Google Calendar API first (steps below).'),
                trailing: FilledButton(onPressed: _busy ? null : _allow, child: const Text('Allow')),
              )
            else
              ListTile(
                key: const ValueKey('calendar-status'),
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Connected'),
                subtitle: Text(lastSync == null ? 'Not synced yet' : 'Last synced ${lastSync.toLocal()}'.split('.').first),
                trailing: TextButton(key: const ValueKey('calendar-sync-now'), onPressed: _busy ? null : _syncNow, child: const Text('Sync now')),
              ),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error, key: const ValueKey('calendar-error'), style: text.bodyMedium!.copyWith(color: scheme.error)),
          ),
        if (_hasCalendar && calendars.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text('CALENDARS · ${calendars.length}', style: text.labelSmall!.copyWith(letterSpacing: 1))),
          GroupedList(
            children: [
              for (final c in calendars)
                SwitchListTile(
                  key: ValueKey('calendar-show-${c.id}'),
                  secondary: CircleAvatar(backgroundColor: Color(c.color), radius: 8),
                  title: Text(c.name),
                  subtitle: Text([if (c.primary) 'Main calendar', if (!c.writable) 'View only'].join(' · ').isEmpty ? 'Shown in the Planner' : [if (c.primary) 'Main calendar', if (!c.writable) 'View only'].join(' · ')),
                  value: !hidden.contains(c.id),
                  onChanged: (v) => ref.read(calendarSyncProvider).setHidden(c.id, !v),
                ),
            ],
          ),
          if (writable.length > 1) ...[
            Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text('NEW EVENTS GO TO', style: text.labelSmall!.copyWith(letterSpacing: 1))),
            DropdownButtonFormField<String>(
              key: const ValueKey('calendar-default'),
              initialValue: defaultId,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [
                for (final c in writable)
                  DropdownMenuItem(value: c.id, child: Row(children: [CircleAvatar(backgroundColor: Color(c.color), radius: 6), const SizedBox(width: 8), Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis))])),
              ],
              onChanged: (v) {
                if (v != null) ref.read(calendarSyncProvider).setDefaultCalendar(v);
              },
            ),
          ],
        ],
        Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text('TURNING ON THE GOOGLE CALENDAR API', style: text.labelSmall!.copyWith(letterSpacing: 1))),
        Text(
          '1. Go to console.cloud.google.com and pick the project you made for ConvoMail.\n'
          '2. Open APIs & Services → Library, search for "Google Calendar API", and press Enable.\n'
          '3. Come back here and press Allow (or Sync now if it is already allowed).',
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/helper_sync.dart';
import '../../../platform/phone_alerts.dart';
import '../../../store/database.dart';
import '../../../store/helper_queries.dart';
import '../../../sync/sent_sound.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';

/// Quiet hours as kept in this device's notes (the same on every device).
final quietHoursProvider = StreamProvider<({bool on, String from, String to})>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(kQuietHours))).watchSingleOrNull().map((row) {
    try {
      final j = jsonDecode(row?.value ?? '') as Map;
      return (on: j['on'] == true, from: '${j['from'] ?? '22:00'}', to: '${j['to'] ?? '07:00'}');
    } catch (_) {
      return (on: false, from: '22:00', to: '07:00');
    }
  });
});

/// Whether a sound plays when mail has gone out.
final sentSoundOnProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(kSentSound))).watchSingleOrNull().map((row) => row?.value != '0');
});

/// The switch for the "sent" sound. Shown on every device, with or without a helper.
class SentSoundSetting extends ConsumerWidget {
  const SentSoundSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GroupedList(
      children: [
        SwitchListTile(
          key: const ValueKey('sound-sent'),
          secondary: Icon(Icons.volume_up_outlined, color: scheme.primary),
          title: const Text('Play a sound when mail has gone out'),
          subtitle: const Text('Two soft notes, once the mail server has taken your message.'),
          value: ref.watch(sentSoundOnProvider).value ?? true,
          onChanged: (on) async {
            await ref.read(databaseProvider).putSetting(kSentSound, on ? '1' : '0');
            if (on) await ref.read(sentSoundProvider)();
          },
        ),
      ],
    );
  }
}

/// Whether this phone may ring, as kept in its notes.
final phoneRingProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(kPhoneRing))).watchSingleOrNull().map((row) => row?.value != '0');
});

/// Alerts on phones: what rings, quiet hours (the same on every device),
/// and, on a phone, whether this one rings at all.
class AlertsSettings extends ConsumerWidget {
  const AlertsSettings({super.key});

  static TimeOfDay _time(String clock) {
    final parts = clock.split(':');
    return TimeOfDay(hour: (int.tryParse(parts.first) ?? 0) % 24, minute: (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0) % 60);
  }

  static String _clock(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final link = ref.watch(helperProvider);
    if (!link.connected) return const SizedBox.shrink();
    final quiet = ref.watch(quietHoursProvider).value ?? (on: false, from: '22:00', to: '07:00');
    final state = ref.watch(phoneAlertStateProvider);
    final ring = ref.watch(phoneRingProvider).value ?? true;

    Future<void> setQuiet({bool? on, String? from, String? to}) async {
      final next = {'on': on ?? quiet.on, 'from': from ?? quiet.from, 'to': to ?? quiet.to};
      final db = ref.read(databaseProvider);
      await db.putSetting(kQuietHours, jsonEncode(next));
      await db.noteForHelper('pref', 'quiet', next);
    }

    Future<void> pick(bool isFrom) async {
      final picked = await showTimePicker(context: context, initialTime: _time(isFrom ? quiet.from : quiet.to), helpText: isFrom ? 'Quiet hours start' : 'Quiet hours end');
      if (picked != null) await setQuiet(from: isFrom ? _clock(picked) : null, to: isFrom ? null : _clock(picked));
    }

    final here = switch (state) {
      PhoneAlertState.on => 'On. This phone rings when something needs you.',
      PhoneAlertState.off => 'Off. This phone stays silent; your other devices are not changed.',
      PhoneAlertState.notSetUp => 'Alerts are not set up on the helper yet. That is done once, on the helper’s own page, under “Alerts to phones”.',
      PhoneAlertState.blocked => 'Android is not letting Précis show alerts. Allow them in the phone’s settings for Précis, then turn this on again.',
      PhoneAlertState.failed => 'This phone could not sign up with Google’s alert service. Précis tries again the next time it opens.',
      PhoneAlertState.notJoined => 'This phone is not joined to the helper.',
      PhoneAlertState.notAPhone => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alerts on your phones', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: AppSpace.sm),
        Text(
          'A phone rings when an email needs you, when a reminder you set comes due, and once, an hour before a “by” time. Feed and Noise never ring. While Précis is open in front of you on a PC, phones stay silent.',
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpace.sm),
        GroupedList(
          children: [
            if (state != PhoneAlertState.notAPhone)
              SwitchListTile(
                key: const ValueKey('alerts-ring-here'),
                secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
                title: const Text('Ring on this phone'),
                subtitle: Text(here),
                value: ring,
                onChanged: (on) => ref.read(phoneAlertsProvider).setRing(on),
              ),
            SwitchListTile(
              key: const ValueKey('alerts-quiet'),
              secondary: Icon(Icons.bedtime_outlined, color: scheme.primary),
              title: const Text('Quiet hours'),
              subtitle: const Text('During these hours an alert still arrives, but without a sound. The same on every phone.'),
              value: quiet.on,
              onChanged: (on) => setQuiet(on: on),
            ),
            if (quiet.on)
              ListTile(
                key: const ValueKey('alerts-quiet-times'),
                leading: const SizedBox(width: 24),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('From'),
                    OutlinedButton(key: const ValueKey('alerts-quiet-from'), onPressed: () => pick(true), child: Text(_time(quiet.from).format(context))),
                    const Text('to'),
                    OutlinedButton(key: const ValueKey('alerts-quiet-to'), onPressed: () => pick(false), child: Text(_time(quiet.to).format(context))),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }
}

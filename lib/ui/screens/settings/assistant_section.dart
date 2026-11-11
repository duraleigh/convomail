import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/helper_client.dart';
import '../../../helper/helper_sync.dart';
import '../../widgets/grouped_list.dart';

/// Millionths of a dollar as "$1.23" (or "$0.004" when under a cent).
String dollars(int micro) {
  final d = micro / 1000000;
  if (d > 0 && d < 0.01) return '\$${d.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '')}';
  return '\$${d.toStringAsFixed(2)}';
}

/// Settings → The assistant and its cost: whether it is on, what this month
/// has cost, the ceiling, and the switch that turns it off.
///
/// The key itself is never entered or shown here. It lives, locked, on the
/// helper, and is typed only into the helper's own page.
class AssistantDetail extends ConsumerStatefulWidget {
  const AssistantDetail({super.key});

  @override
  ConsumerState<AssistantDetail> createState() => _AssistantDetailState();
}

class _AssistantDetailState extends ConsumerState<AssistantDetail> {
  final _ceiling = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ref.read(helperProvider).connected) unawaited(ref.read(helperProvider.notifier).refreshStatus());
    });
  }

  Future<void> _open() async {
    final helper = ref.read(helperProvider.notifier);
    if (!ref.read(helperProvider).loaded) await helper.load();
    if (ref.read(helperProvider).connected) await helper.refreshStatus();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ceiling.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on HelperException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final link = ref.watch(helperProvider);
    Widget heading(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(s, style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8)));
    final intro = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'The assistant is Claude, reached with your own Anthropic key. It reads the new words of mail from people and the first part of other mail, and writes one sentence for each. It never sends, deletes or changes anything.',
        style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
      ),
    );

    if (!link.connected) {
      return ListView(
        children: [
          intro,
          const GroupedList(children: [
            ListTile(
              key: ValueKey('assistant-no-helper'),
              leading: Icon(Icons.link_off_rounded),
              title: Text('This PC does not follow a helper'),
              subtitle: Text('The assistant lives on the helper. Join it under Your devices first.'),
            ),
          ]),
        ],
      );
    }

    final a = ((link.status?['assistant']) as Map?)?.cast<String, Object?>();
    if (a == null) {
      return ListView(children: [intro, const GroupedList(children: [ListTile(leading: Icon(Icons.hourglass_empty_rounded), title: Text('Asking the helper how the assistant is doing…'))])]);
    }
    final hasKey = a['hasKey'] == true;
    final on = a['on'] == true;
    final problem = (a['problem'] as String?) ?? '';
    final month = (a['month'] as num?)?.toInt() ?? 0;
    final today = (a['today'] as num?)?.toInt() ?? 0;
    final ceiling = (a['ceiling'] as num?)?.toInt() ?? 0;
    final reader = (a['modelName'] as String?) ?? '';
    final host = Uri.tryParse(link.address ?? '')?.host ?? (link.address ?? 'the helper');

    return ListView(
      children: [
        intro,
        GroupedList(
          children: [
            if (!hasKey)
              ListTile(
                key: const ValueKey('assistant-no-key'),
                leading: const Icon(Icons.key_off_outlined),
                title: const Text('No key yet'),
                subtitle: Text('Open $host in your browser and paste your Anthropic key into the card named “The assistant”. It is never typed into this app.'),
              )
            else
              SwitchListTile(
                key: const ValueKey('assistant-switch'),
                secondary: Icon(problem.isNotEmpty ? Icons.pause_circle_outline_rounded : Icons.auto_awesome_rounded, color: problem.isNotEmpty ? scheme.error : null),
                title: Text(problem.isNotEmpty ? 'Paused' : (on ? 'On' : 'Off')),
                subtitle: Text(problem.isNotEmpty
                    ? problem
                    : on
                        ? 'Reading with $reader. Turn this off and nothing more is sent to it, on any device.'
                        : reader.isEmpty
                            ? 'A reader has not been chosen yet.'
                            : 'Nothing is sent to it. Focus and the sentences go quiet, and mail is sorted by the fixed rules.'),
                value: on,
                onChanged: _busy || reader.isEmpty ? null : (v) => _run(() => ref.read(helperProvider.notifier).setAssistant(on: v)),
              ),
          ],
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const ValueKey('assistant-error'), style: text.bodyMedium!.copyWith(color: scheme.error))),
        if (hasKey) ...[
          heading('WHAT IT HAS COST'),
          GroupedList(
            children: [
              ListTile(
                key: const ValueKey('assistant-month'),
                leading: const Icon(Icons.speed_rounded),
                title: Text('${dollars(month)} this month'),
                subtitle: Text('Today ${dollars(today)}. Counted from what Anthropic reports each reading used.'),
              ),
              ListTile(
                key: const ValueKey('assistant-ceiling'),
                leading: const Icon(Icons.vertical_align_top_rounded),
                title: Text('Ceiling: ${dollars(ceiling)} a month'),
                subtitle: const Text('When a month reaches it, the assistant pauses and says so. Mail keeps flowing.'),
                trailing: SizedBox(
                  width: 190,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('assistant-ceiling-field'),
                          controller: _ceiling,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, prefixText: '\$', hintText: 'new amount'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        key: const ValueKey('assistant-ceiling-save'),
                        onPressed: _busy
                            ? null
                            : () {
                                final v = double.tryParse(_ceiling.text.trim().replaceAll('\$', '').replaceAll(',', ''));
                                if (v == null || v < 0 || v > 10000) {
                                  setState(() => _error = 'Type the ceiling as a number of dollars a month, such as 10.');
                                  return;
                                }
                                _run(() async {
                                  await ref.read(helperProvider.notifier).setAssistant(ceilingMicro: (v * 1000000).round());
                                  _ceiling.clear();
                                });
                              },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          heading('WHAT IT HAS READ'),
          GroupedList(
            children: [
              ListTile(
                key: const ValueKey('assistant-read'),
                leading: const Icon(Icons.mark_email_read_outlined),
                title: Text('${(a['read'] as num?)?.toInt() ?? 0} emails read'),
                subtitle: Text('${(a['waiting'] as num?)?.toInt() ?? 0} waiting to be read · ${(a['focus'] as num?)?.toInt() ?? 0} need you now'),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('The key'),
                subtitle: Text('Kept locked on $host. To replace or remove it, open that page in your browser.'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

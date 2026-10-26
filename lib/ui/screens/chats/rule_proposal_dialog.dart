import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/classifier.dart';
import '../../../store/classification_queries.dart';
import '../../../store/database.dart' hide ClassificationRule;
import '../../../sync/classification_service.dart';
import '../../theme/tokens.dart';

/// Outcome of the correction flow (spec 4.11): the user accepted a rule
/// (possibly edited), chose to fix only this message, or cancelled.
sealed class CorrectionOutcome {
  const CorrectionOutcome();
}

class RuleAccepted extends CorrectionOutcome {
  const RuleAccepted(this.rule, {required this.retroactive});
  final ClassificationRule rule;
  final bool retroactive;
}

class JustThisOnce extends CorrectionOutcome {
  const JustThisOnce();
}

/// Shows the rule the app would write, in plain language, with Accept /
/// Edit / Just this once. Returns null when dismissed.
Future<CorrectionOutcome?> showRuleProposal(BuildContext context, {required ClassificationRule proposal, required String title, required Message message}) {
  return showDialog<CorrectionOutcome>(
    context: context,
    builder: (_) => _RuleProposalDialog(proposal: proposal, title: title, message: message),
  );
}

class _RuleProposalDialog extends ConsumerStatefulWidget {
  const _RuleProposalDialog({required this.proposal, required this.title, required this.message});
  final ClassificationRule proposal;
  final String title;
  final Message message;

  @override
  ConsumerState<_RuleProposalDialog> createState() => _RuleProposalDialogState();
}

class _RuleProposalDialogState extends ConsumerState<_RuleProposalDialog> {
  late String _field = widget.proposal.field;
  late final _pattern = TextEditingController(text: widget.proposal.pattern);
  late Bucket? _bucket = widget.proposal.bucket;
  late String? _category = widget.proposal.category;
  bool _editing = false;
  bool _retroactive = true;

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  ClassificationRule get _rule => ClassificationRule(field: _field, pattern: _pattern.text.trim(), bucket: _bucket, category: _category);

  String get _domain {
    final a = widget.message.fromAddress;
    return a.contains('@') ? a.substring(a.indexOf('@') + 1).toLowerCase() : a;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final listId = BulkSignals.decode(widget.message.bulkSignals).listIdValue;
    final categories = ref.watch(_categoriesProvider).value ?? const <String>[];

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To prevent the same mistake, ConvoMail can remember a rule:', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.md),
            Container(
              key: const ValueKey('proposal-text'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
              child: Text(_rule.describe(), style: text.titleSmall!.copyWith(color: scheme.onSecondaryContainer)),
            ),
            if (_editing) ...[
              const SizedBox(height: AppSpace.lg),
              Text('Applies to', style: text.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: Text('This address (${widget.message.fromAddress})'), selected: _field == 'sender', onSelected: (_) => setState(() {
                        _field = 'sender';
                        _pattern.text = widget.message.fromAddress.toLowerCase();
                      })),
                  ChoiceChip(label: Text('Anyone at $_domain'), selected: _field == 'domain', onSelected: (_) => setState(() {
                        _field = 'domain';
                        _pattern.text = _domain;
                      })),
                  if (listId != null && listId.isNotEmpty)
                    ChoiceChip(label: Text('The list $listId'), selected: _field == 'listId', onSelected: (_) => setState(() {
                          _field = 'listId';
                          _pattern.text = listId;
                        })),
                  ChoiceChip(label: const Text('Subject contains…'), selected: _field == 'subject', onSelected: (_) => setState(() {
                        _field = 'subject';
                        _pattern.text = widget.message.subject.split(RegExp(r'\s+')).take(2).join(' ').toLowerCase();
                      })),
                ],
              ),
              if (_field == 'subject') ...[
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _pattern,
                  decoration: const InputDecoration(labelText: 'Words (separate alternatives with |)', isDense: true, border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Text('Goes to', style: text.labelLarge),
                  const SizedBox(width: 12),
                  SegmentedButton<Bucket?>(
                    segments: const [
                      ButtonSegment(value: Bucket.people, label: Text('People')),
                      ButtonSegment(value: Bucket.feeds, label: Text('Feeds')),
                      ButtonSegment(value: null, label: Text('Keep bucket')),
                    ],
                    selected: {_bucket},
                    onSelectionChanged: (s) => setState(() => _bucket = s.first),
                    showSelectedIcon: false,
                  ),
                ],
              ),
              if (_bucket != Bucket.people) ...[
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Text('Category', style: text.labelLarge),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: categories.contains(_category) ? _category : null,
                      hint: const Text('Sender default'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Sender default')),
                        for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: AppSpace.md),
            CheckboxListTile(
              key: const ValueKey('proposal-retroactive'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _retroactive,
              onChanged: (v) => setState(() => _retroactive = v ?? true),
              title: const Text('Also apply to mail already here'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const ValueKey('proposal-once'), onPressed: () => Navigator.pop(context, const JustThisOnce()), child: const Text('Just this once')),
        if (!_editing) TextButton(key: const ValueKey('proposal-edit'), onPressed: () => setState(() => _editing = true), child: const Text('Edit')),
        FilledButton(
          key: const ValueKey('proposal-accept'),
          onPressed: _pattern.text.trim().isEmpty || (_bucket == null && _category == null) ? null : () => Navigator.pop(context, RuleAccepted(_rule, retroactive: _retroactive)),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

final _categoriesProvider = FutureProvider<List<String>>((ref) => ref.watch(databaseProvider).categoryNames());

/// Runs the whole correction for a sender move or a category change:
/// proposes the rule, then applies the user's choice. Returns true when
/// something was changed.
Future<bool> correctClassification(
  BuildContext context,
  WidgetRef ref, {
  required Message message,
  Bucket? bucket,
  String? category,
  required String title,
}) async {
  final service = ref.read(classificationServiceProvider);
  final proposal = await service.proposeRule(message, bucket: bucket, category: category);
  if (!context.mounted) return false;
  final outcome = await showRuleProposal(context, proposal: proposal, title: title, message: message);
  switch (outcome) {
    case RuleAccepted(:final rule, :final retroactive):
      await service.acceptRule(rule, retroactive: retroactive);
      if (!retroactive) {
        // The rule covers the future; this message still gets the fix.
        if (bucket != null) await service.setMessageBucket(message.id, bucket);
        if (category != null) await service.setMessageCategory(message.id, category);
      }
      return true;
    case JustThisOnce():
      if (bucket != null) await service.setMessageBucket(message.id, bucket);
      if (category != null) await service.setMessageCategory(message.id, category);
      return true;
    case null:
      return false;
  }
}

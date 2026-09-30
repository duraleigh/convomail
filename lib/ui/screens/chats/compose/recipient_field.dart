import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../mail/models.dart';
import '../../../../store/compose_queries.dart';
import '../../../../store/database.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/tonal_avatar.dart';

/// Parses `Name <addr>`, `addr`, or a comma/semicolon list into addresses.
/// Returns null when nothing in [input] is a valid address.
List<RemoteAddress>? parseRecipients(String input) {
  final out = <RemoteAddress>[];
  for (final raw in input.split(RegExp(r'[;,]'))) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final m = RegExp(r'^(?:"?([^"<]*)"?\s*)?<([^>]+)>$').firstMatch(t);
    final address = (m?.group(2) ?? t).trim();
    final name = (m?.group(1) ?? '').trim();
    if (!isValidAddress(address)) continue;
    out.add(RemoteAddress(address, name));
  }
  return out.isEmpty ? null : out;
}

bool isValidAddress(String s) => RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(s.trim());

/// One recipient line (To / Cc / Bcc): chips for entered addresses and a
/// text field with autocomplete from known contacts (spec 4.4, 5.2 #3).
class RecipientField extends ConsumerStatefulWidget {
  const RecipientField({super.key, required this.label, required this.recipients, required this.onChanged, this.trailing, this.autofocus = false, this.focusNode});

  final String label;
  final List<RemoteAddress> recipients;
  final ValueChanged<List<RemoteAddress>> onChanged;
  final Widget? trailing;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  ConsumerState<RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState extends ConsumerState<RecipientField> {
  final _controller = TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode(debugLabel: 'recipients-${widget.label}');
  double _fieldWidth = 360;

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _add(List<RemoteAddress> list) {
    final existing = {for (final r in widget.recipients) r.address.toLowerCase()};
    final merged = [...widget.recipients, ...list.where((a) => !existing.contains(a.address.toLowerCase()))];
    widget.onChanged(merged);
    _controller.clear();
  }

  void _commitText() {
    final parsed = parseRecipients(_controller.text);
    if (parsed != null) _add(parsed);
  }

  void _remove(RemoteAddress a) => widget.onChanged([
    for (final r in widget.recipients)
      if (r != a) r,
  ]);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final db = ref.watch(databaseProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 64,
              child: Text(widget.label, style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ),
          Expanded(
            child: RawAutocomplete<RecipientSuggestion>(
              textEditingController: _controller,
              focusNode: _focus,
              displayStringForOption: (o) => o.address,
              optionsBuilder: (v) async {
                final q = v.text.trim();
                if (q.isEmpty) return const Iterable<RecipientSuggestion>.empty();
                final existing = {for (final r in widget.recipients) r.address.toLowerCase()};
                final found = await db.searchRecipients(q);
                return found.where((s) => !existing.contains(s.address.toLowerCase()));
              },
              onSelected: (s) => _add([s.toAddress()]),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    _fieldWidth = constraints.maxWidth;
                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) return KeyEventResult.ignored;
                        if (event.logicalKey == LogicalKeyboardKey.backspace && controller.text.isEmpty && widget.recipients.isNotEmpty) {
                          _remove(widget.recipients.last);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.tab && controller.text.trim().isNotEmpty) {
                          _commitText();
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final r in widget.recipients)
                            InputChip(
                              key: ValueKey('chip-${widget.label}-${r.address}'),
                              avatar: TonalAvatar(identityKey: r.address.toLowerCase(), name: r.name.isEmpty ? r.address : r.name, size: 24),
                              label: Text(r.name.isEmpty ? r.address : r.name),
                              tooltip: r.address,
                              onDeleted: () => _remove(r),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 160, maxWidth: 420),
                            child: IntrinsicWidth(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                autofocus: widget.autofocus,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  hintText: widget.recipients.isEmpty ? 'Name or address' : '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (v) {
                                  if (v.endsWith(',') || v.endsWith(';') || (v.endsWith(' ') && isValidAddress(v.trim()))) _commitText();
                                },
                                onSubmitted: (_) {
                                  _commitText();
                                  onFieldSubmitted();
                                },
                                onEditingComplete: _commitText,
                                onTapOutside: (_) => _commitText(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final width = _fieldWidth.clamp(280.0, 520.0);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 3,
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppShapes.md),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: width,
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          for (final o in options)
                            ListTile(
                              dense: true,
                              leading: TonalAvatar(identityKey: o.contactKey, name: o.name.isEmpty ? o.address : o.name, size: 32),
                              title: Text(o.name.isEmpty ? o.address : o.name),
                              subtitle: o.name.isEmpty ? null : Text(o.address),
                              onTap: () => onSelected(o),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.trailing != null) Padding(padding: const EdgeInsets.only(top: 4), child: widget.trailing!),
        ],
      ),
    );
  }
}

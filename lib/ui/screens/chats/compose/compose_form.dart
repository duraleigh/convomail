import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' show Value;
import 'package:enough_mail/enough_mail.dart' show MediaType;
import 'package:file_selector/file_selector.dart' show openFiles;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/account_scope.dart';
import '../../../../app/compose_state.dart';
import '../../../../mail/mail_transport.dart';
import '../../../../mail/models.dart';
import '../../../../mail/outgoing.dart';
import '../../../../store/compose_queries.dart';
import '../../../../store/database.dart';
import '../../../../store/sync_queries.dart';
import '../../../../sync/send_service.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/wavy_progress.dart';
import 'compose_editor.dart';
import 'recipient_field.dart';

/// Every identity across accounts, for the From selector.
final allIdentitiesProvider = StreamProvider<List<Identity>>((ref) => ref.watch(databaseProvider).watchAllIdentities());

/// Shared composer used by the right-pane new message and the inline reply
/// (spec 4.4). Owns recipients, subject, editor, attachments, autosave, and
/// the send flow with progress and failure feedback.
class ComposeForm extends ConsumerStatefulWidget {
  const ComposeForm({
    super.key,
    required this.request,
    required this.onClose,
    this.compact = false,
    this.existingDraft,
    this.header,
  });

  final ComposeRequest request;

  /// Called after send, discard, or close.
  final VoidCallback onClose;

  /// Inline reply layout: bounded editor height, tighter padding.
  final bool compact;

  /// A saved draft to resume instead of starting fresh.
  final Draft? existingDraft;

  /// Optional row above the fields (title + close button).
  final Widget? header;

  @override
  ConsumerState<ComposeForm> createState() => _ComposeFormState();
}

class _ComposeFormState extends ConsumerState<ComposeForm> {
  final _subject = TextEditingController();
  final _toFocus = FocusNode(debugLabel: 'compose-to');
  final _editorFocus = FocusNode(debugLabel: 'compose-editor');
  ComposeEditorController? _editor;

  List<RemoteAddress> _to = [];
  List<RemoteAddress> _cc = [];
  List<RemoteAddress> _bcc = [];
  bool _showCcBcc = false;
  final List<OutgoingAttachment> _attachments = [];
  bool _includeQuote = true;
  int? _accountId;
  int? _identityId;
  int? _draftId;
  Message? _original;
  bool _loading = true;
  bool _dragging = false;
  bool _sending = false;
  String? _error;
  Timer? _saveTimer;
  late final String _token = 'compose-$hashCode';
  late final SendProgressNotifier _progress;

  AppDatabase get _db => ref.read(databaseProvider);

  /// A resumed draft keeps its own kind (reply vs forward).
  String get _kind => widget.existingDraft?.kind ?? widget.request.kind;

  @override
  void initState() {
    super.initState();
    _progress = ref.read(sendProgressProvider.notifier);
    _subject.addListener(_touched);
    unawaited(_init());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _subject.dispose();
    _toFocus.dispose();
    _editorFocus.dispose();
    _editor?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final req = widget.request;
    final draft = widget.existingDraft;
    Identity? identity;
    String? bodyJson;
    String? bodyHtml;

    if (req.messageId != null) {
      _original = await _db.messageById(req.messageId!);
    } else if (draft?.inReplyToMessageId != null) {
      _original = await _db.messageById(draft!.inReplyToMessageId!);
    }

    if (draft != null) {
      _accountId = draft.accountId;
      _identityId = draft.identityId;
      _to = AddressJson.decode(draft.recipientsTo);
      _cc = AddressJson.decode(draft.recipientsCc);
      _bcc = AddressJson.decode(draft.recipientsBcc);
      _showCcBcc = _cc.isNotEmpty || _bcc.isNotEmpty;
      _subject.text = draft.subject;
      _includeQuote = draft.includeQuote;
      _draftId = draft.id;
      bodyJson = draft.bodyJson;
      bodyHtml = draft.bodyHtml;
      try {
        for (final j in (jsonDecode(draft.attachmentsJson) as List)) {
          final a = OutgoingAttachment.fromJson(j as Map<String, dynamic>);
          if (a != null && File(a.path!).existsSync()) _attachments.add(a);
        }
      } catch (_) {}
      if (_identityId != null) identity = await _db.identityById(_identityId!);
    } else {
      final original = _original;
      if (original != null) {
        _accountId = original.accountId;
        identity = await _db.identityForReply(original.accountId, original.id);
        _identityId = identity?.id;
        final parts = await _db.participantsOf(original.id);
        final others = parts.where((p) => !p.isMe);
        RemoteAddress addr(MessageParticipant p) => RemoteAddress(p.address, p.name);
        if (req.isForward) {
          _subject.text = SendService.derivedSubject(original, forward: true);
        } else {
          _subject.text = SendService.derivedSubject(original, forward: false);
          if (original.isFromMe) {
            _to = others.where((p) => p.role == 'to').map(addr).toList();
          } else {
            _to = [RemoteAddress(original.fromAddress, original.fromName)];
          }
          if (req.isReplyAll) {
            final seen = {for (final a in _to) a.address.toLowerCase()};
            final extraTo = others.where((p) => p.role == 'to' && !seen.contains(p.address.toLowerCase())).map(addr);
            _to = [..._to, ...extraTo];
            seen.addAll(_to.map((a) => a.address.toLowerCase()));
            _cc = others.where((p) => p.role == 'cc' && !seen.contains(p.address.toLowerCase())).map(addr).toList();
            _showCcBcc = _cc.isNotEmpty;
          }
        }
      } else {
        final accounts = await _db.allAccounts();
        final scope = ref.read(accountScopeProvider);
        final account = accounts.where((a) => a.id == scope).firstOrNull ?? accounts.where((a) => a.enabled).firstOrNull ?? accounts.firstOrNull;
        _accountId = account?.id;
        if (account != null) {
          identity = (await _db.identitiesForAccount(account.id)).firstOrNull;
          _identityId = identity?.id;
        }
        _to = [for (final t in req.to) ...?parseRecipients(t)];
        _subject.text = req.subject;
        if (req.body.isNotEmpty) bodyHtml = '<p>${const HtmlEscape().convert(req.body)}</p>';
      }
    }

    final signature = identity?.signature.trim() ?? '';
    _editor = ComposeEditorController(
      bodyJson: bodyJson,
      html: bodyHtml,
      signatureLines: signature.isEmpty || draft != null ? const [] : signature.split('\n'),
    );
    _editor!.addListener(_touched);
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_to.isEmpty) {
        _toFocus.requestFocus();
      } else {
        _editorFocus.requestFocus();
      }
    });
  }

  // ---- drafts ----------------------------------------------------------------

  void _touched() {
    if (_loading) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), () => unawaited(_saveDraft()));
  }

  bool get _hasContent => _to.isNotEmpty || _cc.isNotEmpty || _bcc.isNotEmpty || _subject.text.trim().isNotEmpty || !(_editor?.isEmpty ?? true) || _attachments.isNotEmpty;

  Future<void> _saveDraft() async {
    if (!mounted || _accountId == null || _editor == null) return;
    if (!_hasContent) {
      if (_draftId != null) {
        await _db.deleteDraft(_draftId!);
        _draftId = null;
      }
      return;
    }
    final id = await _db.saveDraft(DraftsCompanion(
      id: _draftId == null ? const Value.absent() : Value(_draftId!),
      accountId: Value(_accountId!),
      identityId: Value(_identityId),
      kind: Value(_kind),
      rowKey: Value(widget.request.rowKey ?? widget.existingDraft?.rowKey),
      inReplyToMessageId: Value(_original?.id),
      recipientsTo: Value(AddressJson.encode(_to)),
      recipientsCc: Value(AddressJson.encode(_cc)),
      recipientsBcc: Value(AddressJson.encode(_bcc)),
      subject: Value(_subject.text),
      bodyJson: Value(_editor!.toJson()),
      bodyHtml: Value(_editor!.toHtml()),
      attachmentsJson: Value(jsonEncode([for (final a in _attachments) a.toJson()])),
      includeQuote: Value(_includeQuote),
    ));
    if (mounted) _draftId = id;
  }

  Future<void> _discard() async {
    _saveTimer?.cancel();
    if (_draftId != null) await _db.deleteDraft(_draftId!);
    _draftId = null;
    widget.onClose();
  }

  Future<void> _close() async {
    _saveTimer?.cancel();
    await _saveDraft();
    widget.onClose();
  }

  // ---- attachments -----------------------------------------------------------

  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        if (_attachments.any((a) => a.path == path)) continue;
        _attachments.add(OutgoingAttachment(fileName: p.basename(path), mimeType: MediaType.guessFromFileName(path).text, path: path));
      }
    });
    _touched();
  }

  // ---- send ------------------------------------------------------------------

  Future<void> _send() async {
    if (_sending || _editor == null) return;
    if (_to.isEmpty && _cc.isEmpty && _bcc.isEmpty) {
      setState(() => _error = 'Add at least one recipient.');
      _toFocus.requestFocus();
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Add an account in Settings before sending.');
      return;
    }
    _saveTimer?.cancel();
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    await _saveDraft();
    final submission = ComposeSubmission(
      accountId: _accountId!,
      identityId: _identityId,
      to: _to,
      cc: _cc,
      bcc: _bcc,
      subject: _subject.text.trim(),
      bodyHtml: _editor!.toHtml(),
      attachments: _attachments,
      inReplyToMessageId: _original?.id,
      kind: _kind,
      includeQuote: _includeQuote,
      draftId: _draftId,
    );
    final recipientsLabel = _to.isNotEmpty ? (_to.first.name.isEmpty ? _to.first.address : _to.first.name) + (_to.length > 1 ? ' +${_to.length - 1}' : '') : '${_cc.length + _bcc.length} recipients';
    try {
      await ref.read(sendServiceProvider).send(submission, token: _token);
      if (!mounted) return;
      _draftId = null;
      _progress.clear(_token);
      messenger?.showSnackBar(SnackBar(content: Text('Sent to $recipientsLabel'), behavior: SnackBarBehavior.floating, width: 360));
      widget.onClose();
    } on MailTransportException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_loading || _editor == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final identities = ref.watch(allIdentitiesProvider).value ?? const <Identity>[];
    final progress = ref.watch(sendProgressProvider)[_token];
    final inFlight = _sending && (progress?.inFlight ?? true);
    final showQuoteToggle = _original != null && _kind != 'forward';

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (identities.length > 1 || !widget.compact) _fromRow(identities, scheme, text),
        RecipientField(
          label: 'To',
          recipients: _to,
          focusNode: _toFocus,
          onChanged: (v) {
            setState(() => _to = v);
            _touched();
          },
          trailing: _showCcBcc
              ? null
              : TextButton(onPressed: () => setState(() => _showCcBcc = true), child: const Text('Cc/Bcc')),
        ),
        if (_showCcBcc) ...[
          _line(scheme),
          RecipientField(label: 'Cc', recipients: _cc, onChanged: (v) {
            setState(() => _cc = v);
            _touched();
          }),
          _line(scheme),
          RecipientField(label: 'Bcc', recipients: _bcc, onChanged: (v) {
            setState(() => _bcc = v);
            _touched();
          }),
        ],
        _line(scheme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              SizedBox(width: 64, child: Text('Subject', style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant))),
              Expanded(
                child: TextField(
                  key: const ValueKey('compose-subject'),
                  controller: _subject,
                  decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none, hintText: 'Subject', contentPadding: EdgeInsets.symmetric(vertical: 12)),
                  style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _editorFocus.requestFocus(),
                ),
              ),
            ],
          ),
        ),
        _line(scheme),
      ],
    );

    final editor = ComposeEditor(
      controller: _editor!,
      focusNode: _editorFocus,
      onAttachFiles: _addFiles,
      onSend: _send,
      onEscape: _close,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Padding(padding: EdgeInsets.fromLTRB(widget.compact ? 8 : 12, 0, widget.compact ? 8 : 12, 0), child: fields),
        if (widget.compact)
          ConstrainedBox(constraints: const BoxConstraints(minHeight: 180, maxHeight: 340), child: SizedBox(height: 260, child: editor))
        else
          Expanded(child: editor),
        if (_attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _attachments)
                  InputChip(
                    avatar: Icon(_iconFor(a.mimeType), size: 18),
                    label: Text('${a.fileName} · ${formatSize(a.sizeHint)}'),
                    onDeleted: inFlight
                        ? null
                        : () {
                            setState(() => _attachments.remove(a));
                            _touched();
                          },
                  ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: text.bodyMedium!.copyWith(color: scheme.onErrorContainer))),
                  TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: inFlight
              ? Row(
                  children: [
                    Expanded(child: WavyLinearProgress(semanticsLabel: progress?.label ?? 'Sending')),
                    const SizedBox(width: 12),
                    Text(progress?.label ?? 'Sending…', style: text.labelLarge!.copyWith(color: scheme.primary)),
                  ],
                )
              : Row(
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('compose-send'),
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send'),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(message: 'Ctrl+Enter', child: Text('Ctrl+Enter', style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant))),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Attach files',
                      onPressed: () async {
                        final files = await openFiles();
                        if (files.isNotEmpty) _addFiles([for (final f in files) f.path]);
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    if (showQuoteToggle)
                      FilterChip(
                        label: const Text('Include quoted message'),
                        selected: _includeQuote,
                        onSelected: (v) {
                          setState(() => _includeQuote = v);
                          _touched();
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    const Spacer(),
                    TextButton.icon(
                      key: const ValueKey('compose-discard'),
                      onPressed: _discard,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Discard'),
                    ),
                  ],
                ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
      },
      child: FocusTraversalGroup(
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) {
            setState(() => _dragging = false);
            _addFiles([for (final f in d.files) f.path]);
          },
          child: Stack(
            children: [
              body,
              if (_dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppShapes.lg),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('Drop to attach', style: text.titleMedium!.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fromRow(List<Identity> identities, ColorScheme scheme, TextTheme text) {
    final current = identities.where((i) => i.id == _identityId).firstOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              SizedBox(width: 64, child: Text('From', style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant))),
              Expanded(
                child: identities.isEmpty
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No account', style: text.bodyLarge))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          key: const ValueKey('compose-from'),
                          isDense: true,
                          isExpanded: true,
                          value: current?.id ?? identities.first.id,
                          items: [
                            for (final i in identities)
                              DropdownMenuItem(value: i.id, child: Text(i.name.isEmpty ? i.email : '${i.name} <${i.email}>', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (id) {
                            final i = identities.where((x) => x.id == id).firstOrNull;
                            if (i == null) return;
                            setState(() {
                              _identityId = i.id;
                              _accountId = i.accountId;
                            });
                            _touched();
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        _line(scheme),
      ],
    );
  }

  Widget _line(ColorScheme scheme) => Divider(height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.6));

  static IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('spreadsheet') || mime.contains('excel') || mime == 'text/csv') return Icons.table_chart_outlined;
    if (mime.contains('word') || mime.contains('document')) return Icons.description_outlined;
    if (mime.contains('zip') || mime.contains('compressed')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/signature.dart';
import '../../../store/compose_queries.dart';
import '../../../store/database.dart';
import '../../../sync/signature_service.dart';

/// Pictures wider than this are shown and sent smaller (they can be resized
/// by dragging their edges).
const double signaturePictureMaxWidth = 400;

/// One address's signature: text with bold, italic, underline and links,
/// and pictures (GIFs keep moving). Saved as it is edited.
class SignatureEditor extends ConsumerStatefulWidget {
  const SignatureEditor({super.key, required this.identity});
  final Identity identity;

  @override
  ConsumerState<SignatureEditor> createState() => _SignatureEditorState();
}

class _SignatureEditorState extends ConsumerState<SignatureEditor> {
  late EditorState _es;
  StreamSubscription<dynamic>? _changes;
  Timer? _debounce;
  late final SignatureService _service = ref.read(signatureServiceProvider);
  bool _importing = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _service;
    _load(widget.identity);
  }

  void _load(Identity identity) {
    _changes?.cancel();
    _es = EditorState(document: signatureDocument(identity));
    _changes = _es.transactionStream.listen((_) => _changed());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_debounce != null) unawaited(_save());
    _changes?.cancel();
    _es.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _debounce = null;
      unawaited(_save());
    });
  }

  Future<void> _save() => _service.saveSignature(widget.identity.id, _es.document.root.children.toList());

  Future<void> _addPicture() async {
    final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Pictures', extensions: ['gif', 'png', 'jpg', 'jpeg', 'webp'])]);
    if (file == null) return;
    final path = await _service.keepPicture(file.path);
    double? width;
    try {
      final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
      final frame = await codec.getNextFrame();
      if (frame.image.width > signaturePictureMaxWidth) width = signaturePictureMaxWidth;
      frame.image.dispose();
      codec.dispose();
    } catch (_) {}
    final root = _es.document.root;
    final last = root.children.lastOrNull;
    final t = _es.transaction;
    var at = [root.children.length];
    // An empty last line takes the picture's place.
    if (last != null && isEmptyNode(last)) {
      at = last.path;
      t.deleteNode(last);
    }
    t.insertNodes(at, [imageNode(url: path, align: 'left', width: width), paragraphNode()]);
    await _es.apply(t);
  }

  Future<void> _fromGmail() async {
    setState(() {
      _importing = true;
      _note = null;
    });
    final result = await _service.importFromGmail(widget.identity);
    if (!mounted) return;
    final fresh = await ref.read(databaseProvider).identityById(widget.identity.id);
    if (!mounted) return;
    setState(() {
      _importing = false;
      switch (result) {
        case GmailSignatureResult.imported:
          _debounce?.cancel();
          _debounce = null;
          final old = _es;
          _load(fresh ?? widget.identity);
          WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          _note = 'Copied from your Gmail signature.';
        case GmailSignatureResult.notFound:
          _note = 'No Gmail signature found in mail sent from ${widget.identity.email}.';
        case GmailSignatureResult.offline:
          _note = "Couldn't reach Gmail to look. Try again when you're online.";
      }
    });
  }

  Future<void> _clear() async {
    _debounce?.cancel();
    _debounce = null;
    final old = _es;
    await _service.saveSignature(widget.identity.id, const []);
    final fresh = await ref.read(databaseProvider).identityById(widget.identity.id);
    if (!mounted) return;
    setState(() {
      _load(fresh ?? widget.identity);
      _note = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final id = widget.identity.id;
    final editor = AppFlowyEditor(
      key: ObjectKey(_es),
      editorState: _es,
      editorStyle: EditorStyle.desktop(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        textStyleConfiguration: TextStyleConfiguration(
          text: text.bodyMedium!.copyWith(color: scheme.onSurface, height: 1.45),
          bold: const TextStyle(fontWeight: FontWeight.w700),
          href: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
        ),
      ),
      blockComponentBuilders: standardBlockComponentBuilderMap,
      commandShortcutEvents: [
        CommandShortcutEvent(key: 'signature underline', command: 'ctrl+u', getDescription: () => 'Underline', handler: (es) {
          es.toggleAttribute(AppFlowyRichTextKeys.underline);
          return KeyEventResult.handled;
        }),
        ...standardCommandShortcutEvents,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Signature', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
        ),
        DecoratedBox(
          key: ValueKey('identity-signature-$id'),
          decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(4)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 200, child: editor),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _tool(Icons.format_bold_rounded, 'Bold (Ctrl+B)', () => _es.toggleAttribute(AppFlowyRichTextKeys.bold)),
                    _tool(Icons.format_italic_rounded, 'Italic (Ctrl+I)', () => _es.toggleAttribute(AppFlowyRichTextKeys.italic)),
                    _tool(Icons.format_underlined_rounded, 'Underline (Ctrl+U)', () => _es.toggleAttribute(AppFlowyRichTextKeys.underline)),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: ValueKey('signature-picture-$id'),
                      onPressed: _addPicture,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Add picture'),
                    ),
                    TextButton.icon(
                      key: ValueKey('signature-gmail-$id'),
                      onPressed: _importing ? null : _fromGmail,
                      icon: _importing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Use my Gmail signature'),
                    ),
                    TextButton.icon(
                      key: ValueKey('signature-clear-$id'),
                      onPressed: _clear,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(_note!, key: ValueKey('signature-note-$id'), style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onPressed) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon),
      );
}

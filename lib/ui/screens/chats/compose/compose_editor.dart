import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart' hide FloatingToolbar;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../widgets/floating_toolbar.dart';

/// Owns the editor document for one composition and exports it (spec 4.4:
/// block-based editor with headings, lists, bold/italic/underline, inline
/// images).
class ComposeEditorController extends ChangeNotifier {
  ComposeEditorController({String? bodyJson, String? html, List<String> signatureLines = const []}) {
    Document? doc;
    if (bodyJson != null && bodyJson.isNotEmpty) {
      try {
        doc = Document.fromJson(jsonDecode(bodyJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (doc == null && html != null && html.trim().isNotEmpty) {
      try {
        doc = htmlToDocument(html);
      } catch (_) {}
    }
    doc ??= Document.blank(withInitialText: true);
    if (signatureLines.isNotEmpty && (bodyJson == null || bodyJson.isEmpty)) {
      doc.root.insert(paragraphNode());
      for (final line in signatureLines) {
        doc.root.insert(paragraphNode(text: line));
      }
    }
    if (doc.root.children.isEmpty) doc.root.insert(paragraphNode());
    editorState = EditorState(document: doc);
    editorState.transactionStream.listen((_) => notifyListeners());
  }

  late final EditorState editorState;

  /// Editor JSON for the draft table.
  String toJson() => jsonEncode(editorState.document.toJson());

  /// HTML fragment for the outgoing message.
  String toHtml() {
    try {
      return documentToHTML(editorState.document);
    } catch (_) {
      return plainText().split('\n').map((l) => '<p>${const HtmlEscape().convert(l)}</p>').join();
    }
  }

  String plainText() {
    final buf = StringBuffer();
    void walk(Node n) {
      final d = n.delta;
      if (d != null) buf.writeln(d.toPlainText());
      for (final c in n.children) {
        walk(c);
      }
    }
    walk(editorState.document.root);
    return buf.toString().trim();
  }

  bool get isEmpty {
    for (final n in editorState.document.root.children) {
      if (n.type == ImageBlockKeys.type) return false;
      if ((n.delta?.toPlainText().trim() ?? '').isNotEmpty) return false;
      if (n.children.isNotEmpty) return false;
    }
    return true;
  }

  Future<void> insertImage(String path) => editorState.insertImageNode(path);

  @override
  void dispose() {
    editorState.dispose();
    super.dispose();
  }
}

/// The editor plus its Material 3 Expressive floating formatting toolbar.
class ComposeEditor extends StatefulWidget {
  const ComposeEditor({
    super.key,
    required this.controller,
    this.autoFocus = false,
    this.onAttachFiles,
    this.onSend,
    this.onEscape,
    this.focusNode,
  });

  final ComposeEditorController controller;
  final bool autoFocus;

  /// Called from the toolbar's paperclip with the picked paths.
  final void Function(List<String> paths)? onAttachFiles;

  /// Ctrl+Enter.
  final VoidCallback? onSend;

  /// Escape while the editor has focus (the editor would otherwise swallow it).
  final VoidCallback? onEscape;
  final FocusNode? focusNode;

  @override
  State<ComposeEditor> createState() => _ComposeEditorState();
}

class _ComposeEditorState extends State<ComposeEditor> {
  EditorState get _es => widget.controller.editorState;

  late final List<CommandShortcutEvent> _commands = [
    CommandShortcutEvent(
      key: 'paste image from clipboard',
      command: 'ctrl+v',
      getDescription: () => 'Paste an image',
      handler: _pasteImage,
    ),
    CommandShortcutEvent(
      key: 'close composer',
      command: 'escape',
      getDescription: () => 'Close',
      handler: (_) {
        if (widget.onEscape == null) return KeyEventResult.ignored;
        widget.onEscape!();
        return KeyEventResult.handled;
      },
    ),
    CommandShortcutEvent(
      key: 'send message',
      command: 'ctrl+enter',
      getDescription: () => 'Send',
      handler: (_) {
        widget.onSend?.call();
        return KeyEventResult.handled;
      },
    ),
    CommandShortcutEvent(key: 'underline', command: 'ctrl+u', getDescription: () => 'Underline', handler: (es) {
      es.toggleAttribute(AppFlowyRichTextKeys.underline);
      return KeyEventResult.handled;
    }),
    ...standardCommandShortcutEvents,
  ];

  /// The standard paste runs when the clipboard has text. When it holds
  /// only an image (a screenshot), the image is written to the app's
  /// compose-images folder and inserted as a block.
  KeyEventResult _pasteImage(EditorState es) {
    () async {
      final text = await Pasteboard.text;
      if (text != null && text.trim().isNotEmpty) return;
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return;
      final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'compose-images'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'pasted-${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(bytes);
      if (mounted) await es.insertImageNode(file.path);
    }();
    return KeyEventResult.ignored;
  }

  Future<void> _pickImage() async {
    final files = await openFiles(acceptedTypeGroups: const [
      XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']),
    ]);
    for (final f in files) {
      await widget.controller.insertImage(f.path);
    }
  }

  Future<void> _pickAttachments() async {
    final files = await openFiles();
    if (files.isNotEmpty) widget.onAttachFiles?.call([for (final f in files) f.path]);
  }

  bool _hasAttr(String key) {
    final sel = _es.selection;
    if (sel == null) return false;
    if (sel.isCollapsed) return _es.toggledStyle[key] == true || (_es.getDeltaAttributeValueInSelection<bool>(key, sel) ?? false);
    return _es.getDeltaAttributeValueInSelection<bool>(key, sel) ?? false;
  }

  Node? _currentNode() {
    final sel = _es.selection;
    if (sel == null) return null;
    return _es.getNodeAtPath(sel.start.path);
  }

  bool _isBlock(String type, {int? level}) {
    final n = _currentNode();
    if (n == null || n.type != type) return false;
    return level == null || n.attributes[HeadingBlockKeys.level] == level;
  }

  Future<void> _setBlock(String type, {int? level}) async {
    final already = _isBlock(type, level: level);
    await _es.formatNode(null, (node) {
      final delta = node.delta?.toJson() ?? [];
      if (already) return node.copyWith(type: ParagraphBlockKeys.type, attributes: {blockComponentDelta: delta});
      return node.copyWith(type: type, attributes: {blockComponentDelta: delta, HeadingBlockKeys.level: ?level});
    });
    _es.selection = _es.selection;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = EditorStyle.desktop(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 72),
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.22),
      textStyleConfiguration: TextStyleConfiguration(
        text: text.bodyLarge!.copyWith(fontSize: 15, height: 1.5, color: scheme.onSurface),
        bold: const TextStyle(fontWeight: FontWeight.w700),
        href: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
        code: TextStyle(fontFamily: 'Cascadia Mono', backgroundColor: scheme.surfaceContainerHigh),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: AppFlowyEditor(
            editorState: _es,
            editorStyle: style,
            autoFocus: widget.autoFocus,
            focusNode: widget.focusNode,
            blockComponentBuilders: standardBlockComponentBuilderMap,
            characterShortcutEvents: standardCharacterShortcutEvents,
            commandShortcutEvents: _commands,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: ValueListenableBuilder<Selection?>(
              valueListenable: _es.selectionNotifier,
              builder: (context, _, _) => FloatingToolbar(
                children: [
                  ToolbarAction(icon: Icons.format_bold_rounded, tooltip: 'Bold (Ctrl+B)', active: _hasAttr(AppFlowyRichTextKeys.bold), onPressed: () => _es.toggleAttribute(AppFlowyRichTextKeys.bold)),
                  ToolbarAction(icon: Icons.format_italic_rounded, tooltip: 'Italic (Ctrl+I)', active: _hasAttr(AppFlowyRichTextKeys.italic), onPressed: () => _es.toggleAttribute(AppFlowyRichTextKeys.italic)),
                  ToolbarAction(icon: Icons.format_underlined_rounded, tooltip: 'Underline (Ctrl+U)', active: _hasAttr(AppFlowyRichTextKeys.underline), onPressed: () => _es.toggleAttribute(AppFlowyRichTextKeys.underline)),
                  ToolbarAction(icon: Icons.strikethrough_s_rounded, tooltip: 'Strikethrough', active: _hasAttr(AppFlowyRichTextKeys.strikethrough), onPressed: () => _es.toggleAttribute(AppFlowyRichTextKeys.strikethrough)),
                  _divider(scheme),
                  ToolbarAction(icon: Icons.title_rounded, tooltip: 'Heading', active: _isBlock(HeadingBlockKeys.type, level: 1), onPressed: () => _setBlock(HeadingBlockKeys.type, level: 1)),
                  ToolbarAction(icon: Icons.text_fields_rounded, tooltip: 'Subheading', active: _isBlock(HeadingBlockKeys.type, level: 2), onPressed: () => _setBlock(HeadingBlockKeys.type, level: 2)),
                  ToolbarAction(icon: Icons.format_list_bulleted_rounded, tooltip: 'Bulleted list', active: _isBlock(BulletedListBlockKeys.type), onPressed: () => _setBlock(BulletedListBlockKeys.type)),
                  ToolbarAction(icon: Icons.format_list_numbered_rounded, tooltip: 'Numbered list', active: _isBlock(NumberedListBlockKeys.type), onPressed: () => _setBlock(NumberedListBlockKeys.type)),
                  ToolbarAction(icon: Icons.format_quote_rounded, tooltip: 'Quote', active: _isBlock(QuoteBlockKeys.type), onPressed: () => _setBlock(QuoteBlockKeys.type)),
                  _divider(scheme),
                  ToolbarAction(icon: Icons.image_outlined, tooltip: 'Insert image', onPressed: _pickImage),
                  if (widget.onAttachFiles != null) ToolbarAction(icon: Icons.attach_file_rounded, tooltip: 'Attach files', onPressed: _pickAttachments),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(ColorScheme scheme) => Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: scheme.onPrimaryContainer.withValues(alpha: 0.25));
}

/// Keyboard shortcut summary shown in Settings → Keyboard.
const List<(String, String)> composeShortcutDescriptions = [
  ('Ctrl+Enter', 'Send'),
  ('Ctrl+B / I / U', 'Bold / Italic / Underline'),
  ('# , - , 1. at line start', 'Heading, bulleted list, numbered list'),
];

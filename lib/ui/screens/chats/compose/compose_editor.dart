import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the editor document for one composition and exports it (spec 4.4:
/// block-based editor with headings, lists, bold/italic/underline, inline
/// images).
class ComposeEditorController extends ChangeNotifier {
  ComposeEditorController({String? bodyJson, String? html, List<Node> signature = const []}) {
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
    if (signature.isNotEmpty && (bodyJson == null || bodyJson.isEmpty)) {
      doc.root.insert(paragraphNode());
      for (final n in signature) {
        doc.root.insert(n);
        _signature.add(n);
      }
    }
    if (doc.root.children.isEmpty) doc.root.insert(paragraphNode());
    editorState = EditorState(document: doc);
    editorState.transactionStream.listen((_) => notifyListeners());
  }

  late final EditorState editorState;

  /// Puts the cursor at the start of the message, where a reply is written
  /// (above the signature). On a phone this is also what brings the
  /// keyboard up for the message, not for another field.
  void cursorToStart() {
    final first = editorState.document.root.children.firstOrNull;
    if (first == null) return;
    editorState.updateSelectionWithReason(Selection.collapsed(Position(path: first.path)), reason: SelectionUpdateReason.uiEvent);
  }

  /// The signature blocks this composer put in, so a change of From address
  /// can swap them for the new address's signature.
  final List<Node> _signature = [];

  /// Replaces the signature put in earlier with [next], keeping its place.
  /// Blocks the user deleted stay deleted; with none left, [next] goes at
  /// the end.
  Future<void> replaceSignature(List<Node> next) async {
    final remaining = _signature.where((n) => n.parent != null && identical(_rootOf(n), editorState.document.root)).toList();
    final t = editorState.transaction;
    Path at;
    if (remaining.isNotEmpty) {
      at = remaining.first.path;
      t.deleteNodes(remaining);
    } else {
      final children = editorState.document.root.children;
      at = [children.length];
      if (next.isNotEmpty && children.isNotEmpty && !(children.last.type == ParagraphBlockKeys.type && (children.last.delta?.isEmpty ?? false))) {
        t.insertNode(at, paragraphNode());
        at = [children.length + 1];
      }
    }
    if (next.isNotEmpty) t.insertNodes(at, next, deepCopy: false);
    _signature
      ..clear()
      ..addAll(next);
    if (t.operations.isNotEmpty) await editorState.apply(t, withUpdateSelection: false);
  }

  static Node _rootOf(Node n) {
    var r = n;
    while (r.parent != null) {
      r = r.parent!;
    }
    return r;
  }

  /// Editor JSON for the draft table.
  String toJson() => jsonEncode(editorState.document.toJson());

  /// HTML fragment for the outgoing message.
  String toHtml() {
    try {
      // Picture sizes as whole pixels: "200", not "200.0".
      return documentToHTML(editorState.document).replaceAllMapped(RegExp(r'(width|height)="(\d+)(?:\.\d+)?"'), (m) => '${m[1]}="${m[2]}"');
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

/// The editor, with a flat formatting bar along its bottom edge when
/// [showToolbar] is on.
class ComposeEditor extends StatefulWidget {
  const ComposeEditor({
    super.key,
    required this.controller,
    this.autoFocus = false,
    this.showToolbar = false,
    this.onAttachFiles,
    this.onSend,
    this.onEscape,
    this.focusNode,
  });

  final ComposeEditorController controller;
  final bool autoFocus;

  /// Shows the formatting bar (bold, lists, quote).
  final bool showToolbar;

  /// Called with paths of files pasted or dropped onto the editor.
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.22),
      textStyleConfiguration: TextStyleConfiguration(
        text: text.bodyLarge!.copyWith(fontSize: 15, height: 1.5, color: scheme.onSurface),
        bold: const TextStyle(fontWeight: FontWeight.w700),
        href: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
        code: TextStyle(fontFamily: 'Cascadia Mono', backgroundColor: scheme.surfaceContainerHigh),
      ),
    );

    final editor = AppFlowyEditor(
      editorState: _es,
      editorStyle: style,
      autoFocus: widget.autoFocus,
      focusNode: widget.focusNode,
      blockComponentBuilders: standardBlockComponentBuilderMap,
      characterShortcutEvents: standardCharacterShortcutEvents,
      commandShortcutEvents: _commands,
    );
    // The formatting bar sits flat along the bottom of the writing area and
    // only when asked for, so it never covers what is being written.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: editor),
        if (widget.showToolbar)
          Container(
            key: const ValueKey('format-bar'),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)))),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ValueListenableBuilder<Selection?>(
              valueListenable: _es.selectionNotifier,
              builder: (context, _, _) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tool(Icons.format_bold_rounded, 'Bold (Ctrl+B)', _hasAttr(AppFlowyRichTextKeys.bold), () => _es.toggleAttribute(AppFlowyRichTextKeys.bold)),
                    _tool(Icons.format_italic_rounded, 'Italic (Ctrl+I)', _hasAttr(AppFlowyRichTextKeys.italic), () => _es.toggleAttribute(AppFlowyRichTextKeys.italic)),
                    _tool(Icons.format_underlined_rounded, 'Underline (Ctrl+U)', _hasAttr(AppFlowyRichTextKeys.underline), () => _es.toggleAttribute(AppFlowyRichTextKeys.underline)),
                    _tool(Icons.strikethrough_s_rounded, 'Strikethrough', _hasAttr(AppFlowyRichTextKeys.strikethrough), () => _es.toggleAttribute(AppFlowyRichTextKeys.strikethrough)),
                    _divider(scheme),
                    _tool(Icons.title_rounded, 'Heading', _isBlock(HeadingBlockKeys.type, level: 1), () => _setBlock(HeadingBlockKeys.type, level: 1)),
                    _tool(Icons.text_fields_rounded, 'Subheading', _isBlock(HeadingBlockKeys.type, level: 2), () => _setBlock(HeadingBlockKeys.type, level: 2)),
                    _tool(Icons.format_list_bulleted_rounded, 'Bulleted list', _isBlock(BulletedListBlockKeys.type), () => _setBlock(BulletedListBlockKeys.type)),
                    _tool(Icons.format_list_numbered_rounded, 'Numbered list', _isBlock(NumberedListBlockKeys.type), () => _setBlock(NumberedListBlockKeys.type)),
                    _tool(Icons.format_quote_rounded, 'Quote', _isBlock(QuoteBlockKeys.type), () => _setBlock(QuoteBlockKeys.type)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tool(IconData icon, String tooltip, bool active, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      isSelected: active,
      onPressed: onPressed,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        backgroundColor: active ? scheme.secondaryContainer : null,
      ),
      icon: Icon(icon),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 6), color: scheme.outlineVariant);
}

/// Keyboard shortcut summary shown in Settings → Keyboard.
const List<(String, String)> composeShortcutDescriptions = [
  ('Ctrl+Enter', 'Send'),
  ('Ctrl+B / I / U', 'Bold / Italic / Underline'),
  ('# , - , 1. at line start', 'Heading, bulleted list, numbered list'),
];

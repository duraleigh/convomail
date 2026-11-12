import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/conversation_state.dart';
import '../../app/layout.dart';
import '../../app/people_state.dart';
import '../../app/search_state.dart';
import '../../store/attachment_queries.dart';
import '../../store/database.dart';
import '../../sync/attachment_service.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import 'chats/files/attachment_ui.dart';
import 'chats/people_list_pane.dart' show relativeTime;

/// Every file that came or went by email, newest first.
final allAttachmentsProvider = StreamProvider<List<FoundFile>>((ref) => ref.watch(databaseProvider).watchAllAttachments());

/// Whose mail a file is from, for the filter.
enum FileSource { all, chats, feed }

/// What kind of file it is, for the filter.
enum FileKind {
  all('All kinds'),
  pictures('Pictures'),
  pdf('PDF'),
  documents('Documents'),
  sheets('Spreadsheets'),
  slides('Slides'),
  media('Audio and video'),
  other('Other');

  const FileKind(this.label);
  final String label;

  static FileKind of(Attachment a) {
    final mime = a.mimeType.toLowerCase();
    final ext = a.fileName.contains('.') ? a.fileName.split('.').last.toLowerCase() : '';
    if (mime.startsWith('image/')) return pictures;
    if (mime == 'application/pdf' || ext == 'pdf') return pdf;
    if (mime.contains('spreadsheet') || mime.contains('excel') || mime == 'text/csv' || const {'xls', 'xlsx', 'csv', 'numbers', 'ods', 'tsv'}.contains(ext)) return sheets;
    if (mime.contains('presentation') || mime.contains('powerpoint') || const {'ppt', 'pptx', 'key', 'odp'}.contains(ext)) return slides;
    if (mime.contains('word') || mime.contains('wordprocessing') || mime.startsWith('text/') || const {'doc', 'docx', 'txt', 'rtf', 'pages', 'odt', 'md'}.contains(ext)) return documents;
    if (mime.startsWith('audio/') || mime.startsWith('video/')) return media;
    return other;
  }
}

/// How the list is ordered.
enum FileOrder {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name, A to Z'),
  largest('Largest first'),
  sender('Sender, A to Z'),
  kind('Kind of file');

  const FileOrder(this.label);
  final String label;
}

/// A picture that is part of how an email looks, not something sent to be
/// kept: a logo, a signature picture, a social icon, a tracking dot. They
/// arrive marked as attachments all the same. Told by being meant to sit
/// inside the email, by being tiny, or by the names mail programs give them.
bool looksLikeDecoration(Attachment a) {
  if (!a.mimeType.toLowerCase().startsWith('image/')) return false;
  if ((a.contentId ?? '').isNotEmpty) return true;
  if (a.size > 0 && a.size < 10000) return true;
  return _decorationName.hasMatch(a.fileName.toLowerCase());
}

final _decorationName = RegExp(r'^(image\d{3}\.|outlook-|logo|signature|sig[-_.]|facebook|linkedin|twitter|instagram|youtube|x-logo|spacer|pixel|banner[-_.])|[-_ ](logo|signature|icon)\.');

/// The list as asked for: searched, filtered and put in order. Kept apart
/// from the screen so it can be checked by itself.
List<FoundFile> arrangeFiles(
  List<FoundFile> files, {
  String search = '',
  FileSource source = FileSource.all,
  FileKind kind = FileKind.all,
  FileOrder order = FileOrder.newest,
  bool hideDecoration = true,
}) {
  final words = [for (final w in search.toLowerCase().split(RegExp(r'\s+'))) if (w.isNotEmpty) w];
  final out = [
    for (final f in files)
      if (!(hideDecoration && looksLikeDecoration(f.attachment)))
        if (source == FileSource.all || (source == FileSource.chats) == f.fromPerson)
          if (kind == FileKind.all || FileKind.of(f.attachment) == kind)
            if (words.every((w) => f.searchText.contains(w))) f,
  ];
  int byDate(FoundFile a, FoundFile b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
  switch (order) {
    case FileOrder.newest:
      out.sort(byDate);
    case FileOrder.oldest:
      out.sort((a, b) => byDate(b, a));
    case FileOrder.name:
      out.sort((a, b) => a.attachment.fileName.toLowerCase().compareTo(b.attachment.fileName.toLowerCase()));
    case FileOrder.largest:
      out.sort((a, b) => b.attachment.size.compareTo(a.attachment.size));
    case FileOrder.sender:
      out.sort((a, b) {
        final c = a.senderLabel.toLowerCase().compareTo(b.senderLabel.toLowerCase());
        return c != 0 ? c : byDate(a, b);
      });
    case FileOrder.kind:
      out.sort((a, b) {
        final c = FileTypeStyle.of(a.attachment.mimeType, a.attachment.fileName).label.compareTo(FileTypeStyle.of(b.attachment.mimeType, b.attachment.fileName).label);
        return c != 0 ? c : byDate(a, b);
      });
  }
  return out;
}

/// Attachments: every file in the mailbox in one place, to search, filter,
/// sort, open and save.
class AttachmentsScreen extends ConsumerStatefulWidget {
  const AttachmentsScreen({super.key});

  @override
  ConsumerState<AttachmentsScreen> createState() => _AttachmentsScreenState();
}

class _AttachmentsScreenState extends ConsumerState<AttachmentsScreen> {
  final _search = TextEditingController();
  FileSource _source = FileSource.all;
  FileKind _kind = FileKind.all;
  FileOrder _order = FileOrder.newest;
  bool _grid = false;
  bool _hideDecoration = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Goes to the email the file came with.
  Future<void> _openEmail(FoundFile f) async {
    ref.read(expandedMessagesProvider.notifier).expand(f.message.id);
    ref.read(scrollToMessageProvider.notifier).request(f.message.id);
    await openRow(ref.read, f.rowKey);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final compact = isCompactLayout(context, ref);
    final all = ref.watch(allAttachmentsProvider).value;
    final files = arrangeFiles(all ?? const [], search: _search.text, source: _source, kind: _kind, order: _order, hideDecoration: _hideDecoration);
    final hidden = all == null ? 0 : all.where((f) => looksLikeDecoration(f.attachment)).length;

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 300,
          child: TextField(
            key: const ValueKey('attachments-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: 'Search by file name, sender or subject',
              suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(_search.clear)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppShapes.full)),
            ),
          ),
        ),
        SegmentedButton<FileSource>(
          key: const ValueKey('attachments-source'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: FileSource.all, label: Text('All')),
            ButtonSegment(value: FileSource.chats, label: Text('Chats')),
            ButtonSegment(value: FileSource.feed, label: Text('Feed')),
          ],
          selected: {_source},
          onSelectionChanged: (s) => setState(() => _source = s.first),
        ),
        PopupMenuButton<FileKind>(
          key: const ValueKey('attachments-kind'),
          tooltip: 'Kind of file',
          onSelected: (k) => setState(() => _kind = k),
          itemBuilder: (_) => [for (final k in FileKind.values) CheckedPopupMenuItem(value: k, checked: k == _kind, child: Text(k.label))],
          child: Chip(avatar: const Icon(Icons.filter_list_rounded, size: 18), label: Text(_kind.label)),
        ),
        PopupMenuButton<FileOrder>(
          key: const ValueKey('attachments-order'),
          tooltip: 'Order',
          onSelected: (o) => setState(() => _order = o),
          itemBuilder: (_) => [for (final o in FileOrder.values) CheckedPopupMenuItem(value: o, checked: o == _order, child: Text(o.label))],
          child: Chip(avatar: const Icon(Icons.sort_rounded, size: 18), label: Text(_order.label)),
        ),
        FilterChip(
          key: const ValueKey('attachments-hide-decoration'),
          label: Text(hidden == 0 ? 'Hide logos and signature pictures' : 'Hide logos and signature pictures ($hidden)'),
          selected: _hideDecoration,
          onSelected: (v) => setState(() => _hideDecoration = v),
        ),
        IconButton(
          key: const ValueKey('attachments-view'),
          tooltip: _grid ? 'Show as a list' : 'Show as a grid',
          icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          onPressed: () => setState(() => _grid = !_grid),
        ),
      ],
    );

    Widget body;
    if (all == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (files.isEmpty) {
      body = EmptyState(
        icon: Icons.attach_file_rounded,
        title: all.isEmpty ? 'No attachments yet' : 'Nothing matches',
        message: all.isEmpty ? 'Files sent to you, and files you sent, are listed here as Précis learns of them.' : 'No file fits what you searched for and the filters you chose.',
      );
    } else if (_grid) {
      body = GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.86),
        itemCount: files.length,
        itemBuilder: (context, i) => _Tile(file: files[i], onOpenEmail: () => _openEmail(files[i])),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: files.length,
        itemBuilder: (context, i) => _Row(file: files[i], onOpenEmail: () => _openEmail(files[i])),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 8, compact ? 8 : 12, compact ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Attachments', style: text.headlineMedium),
                const SizedBox(width: 12),
                if (all != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(files.length == 1 ? '1 file' : '${files.length} files', key: const ValueKey('attachments-count'), style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: controls),
          Expanded(
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppShapes.xl),
              clipBehavior: Clip.antiAlias,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.file, required this.onOpenEmail});
  final FoundFile file;
  final VoidCallback onOpenEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = file.attachment;
    final style = FileTypeStyle.of(a.mimeType, a.fileName);
    final downloading = ref.watch(attachmentDownloadsProvider).contains(a.id);
    return ListTile(
      key: ValueKey('attachment-${a.id}'),
      leading: AttachmentThumb(attachment: a, size: 44, radius: AppShapes.sm),
      title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [file.senderLabel, if (a.size > 0) formatFileSize(a.size), relativeTime(file.date), if (file.message.subject.isNotEmpty) file.message.subject].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppShapes.full)),
            child: Text(style.label, style: text.labelSmall!.copyWith(color: style.color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          IconButton(key: ValueKey('attachment-email-${a.id}'), tooltip: 'Open the email it came with', onPressed: onOpenEmail, icon: const Icon(Icons.mail_outline_rounded, size: 20)),
          if (downloading)
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(tooltip: 'Save as…', onPressed: () => saveAttachmentAs(context, ref, a), icon: const Icon(Icons.download_rounded, size: 20)),
        ],
      ),
      onTap: downloading ? null : () => openAttachment(context, ref, a),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.file, required this.onOpenEmail});
  final FoundFile file;
  final VoidCallback onOpenEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = file.attachment;
    final downloading = ref.watch(attachmentDownloadsProvider).contains(a.id);
    return Tooltip(
      message: '${a.fileName}\n${file.senderLabel} · ${formatFileSize(a.size)} · ${relativeTime(file.date)}',
      child: Material(
        key: ValueKey('attachment-${a.id}'),
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: downloading ? null : () => openAttachment(context, ref, a),
          onLongPress: onOpenEmail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(builder: (context, c) => AttachmentThumb(attachment: a, size: c.maxWidth, radius: 0)),
                    if (downloading) const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                    Text('${file.senderLabel} · ${relativeTime(file.date)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

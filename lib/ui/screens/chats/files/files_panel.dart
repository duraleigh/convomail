import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../store/attachment_queries.dart';
import '../../../../store/database.dart';
import '../../../../store/people_queries.dart';
import '../../../../sync/attachment_service.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/connected_button_group.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/grouped_list.dart';
import '../people_list_pane.dart' show relativeTime;
import 'attachment_ui.dart';

/// Whether the Files panel is open for the selected row.
final filesPanelOpenProvider = NotifierProvider<FilesPanelOpenNotifier, bool>(FilesPanelOpenNotifier.new);

class FilesPanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void open() => state = true;
  void close() => state = false;
}

enum FilesView { list, grid }

final filesViewProvider = NotifierProvider<FilesViewNotifier, FilesView>(FilesViewNotifier.new);

class FilesViewNotifier extends Notifier<FilesView> {
  @override
  FilesView build() => FilesView.list;
  void select(FilesView v) => state = v;
}

final rowAttachmentsProvider = StreamProvider.family<List<RowAttachment>, String>((ref, rowKey) => ref.watch(databaseProvider).watchAttachmentsForRow(rowKey));

/// Every attachment exchanged with one person (spec 4.5): List/Grid button
/// group, a featured card for the newest file, a grouped list with type
/// badges, and a photo grid. Slides in over the conversation like the
/// thread overlay.
class FilesPanel extends ConsumerStatefulWidget {
  const FilesPanel({super.key, required this.row});
  final PeopleRow row;

  @override
  ConsumerState<FilesPanel> createState() => _FilesPanelState();
}

class _FilesPanelState extends ConsumerState<FilesPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  final _focus = FocusNode(debugLabel: 'files-panel');
  bool _discovering = true;

  @override
  void initState() {
    super.initState();
    // Take focus so Escape reaches the panel rather than the list behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    // Messages flagged as having attachments but never opened: fetch their
    // bodies so their files show up here.
    unawaited(ref.read(attachmentServiceProvider).discoverForRow(widget.row.rowKey).whenComplete(() {
      if (mounted) setState(() => _discovering = false);
    }));
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _anim.reverse();
    if (mounted) ref.read(filesPanelOpenProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final files = ref.watch(rowAttachmentsProvider(widget.row.rowKey));
    final view = ref.watch(filesViewProvider);

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(onTap: _close, child: FadeTransition(opacity: _anim, child: Container(color: scheme.scrim.withValues(alpha: 0.32)))),
          SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.88,
                child: CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
                  child: Focus(
                    focusNode: _focus,
                    child: Material(
                      color: scheme.surface,
                      elevation: 3,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppShapes.xl)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, color: scheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Files · ${widget.row.title}', style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        files.value == null ? 'Loading…' : '${files.value!.length} file${files.value!.length == 1 ? '' : 's'}${_discovering ? ' · checking older messages…' : ''}',
                                        style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: ConnectedButtonGroup<FilesView>(
                                    selected: view,
                                    onSelected: (v) => ref.read(filesViewProvider.notifier).select(v),
                                    items: const [
                                      ButtonGroupItem(value: FilesView.list, label: 'List', icon: Icons.view_list_rounded),
                                      ButtonGroupItem(value: FilesView.grid, label: 'Grid', icon: Icons.grid_view_rounded),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(tooltip: 'Close (Esc)', onPressed: _close, icon: const Icon(Icons.close_rounded)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: files.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('$e')),
                              data: (list) {
                                if (list.isEmpty) {
                                  return EmptyState(
                                    icon: Icons.attach_file_rounded,
                                    title: 'No files yet',
                                    message: _discovering ? 'Checking this conversation for attachments…' : 'Attachments exchanged with ${widget.row.title.split(' ').first} will show up here.',
                                  );
                                }
                                return view == FilesView.list ? _ListView(files: list) : _GridView(files: list);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Featured card for the newest file, then the rest grouped by month.
class _ListView extends ConsumerWidget {
  const _ListView({required this.files});
  final List<RowAttachment> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final featured = files.first;
    final sections = <String, List<RowAttachment>>{};
    for (final f in files.skip(1)) {
      sections.putIfAbsent(_monthLabel(f.date), () => []).add(f);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _FeaturedCard(file: featured),
        for (final e in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
            child: Text(e.key, style: text.labelSmall!.copyWith(letterSpacing: 1)),
          ),
          GroupedList(
            color: scheme.surfaceContainerLow,
            children: [for (final f in e.value) _FileTile(file: f)],
          ),
        ],
      ],
    );
  }

  static String _monthLabel(DateTime? d) {
    if (d == null) return 'UNDATED';
    final l = d.toLocal();
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    return '${months[l.month - 1]} ${l.year}';
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.file});
  final RowAttachment file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = file.attachment;
    final style = FileTypeStyle.of(a.mimeType, a.fileName);
    final downloading = ref.watch(attachmentDownloadsProvider).contains(a.id);
    return Material(
      key: const ValueKey('files-featured'),
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppShapes.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAttachment(context, ref, a),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AttachmentThumb(attachment: a, size: 112, radius: AppShapes.lg),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOST RECENT', style: text.labelSmall!.copyWith(color: scheme.primary, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(a.fileName, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${file.senderLabel} · ${style.label} · ${formatFileSize(a.size)} · ${relativeTime(file.date)}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: downloading ? null : () => openAttachment(context, ref, a),
                          icon: downloading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(canPreviewInApp(a) ? Icons.visibility_outlined : Icons.open_in_new_rounded, size: 18),
                          label: Text(canPreviewInApp(a) ? 'Quick look' : 'Open'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: downloading ? null : () => saveAttachmentAs(context, ref, a),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Save as…'),
                        ),
                      ],
                    ),
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

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});
  final RowAttachment file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = file.attachment;
    final style = FileTypeStyle.of(a.mimeType, a.fileName);
    final downloading = ref.watch(attachmentDownloadsProvider).contains(a.id);
    return ListTile(
      key: ValueKey('file-${a.id}'),
      leading: AttachmentThumb(attachment: a, size: 44, radius: AppShapes.sm),
      title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${file.senderLabel} · ${formatFileSize(a.size)} · ${relativeTime(file.date)}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppShapes.full)),
            child: Text(style.label, style: text.labelSmall!.copyWith(color: style.color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 4),
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

/// Thumbnail grid of the image attachments (spec 4.5 grid view).
class _GridView extends ConsumerWidget {
  const _GridView({required this.files});
  final List<RowAttachment> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final images = files.where((f) => f.isImage).toList();
    final others = files.length - images.length;
    if (images.isEmpty) {
      return EmptyState(icon: Icons.photo_library_outlined, title: 'No photos', message: 'The ${files.length} file${files.length == 1 ? '' : 's'} here ${files.length == 1 ? 'is' : 'are'} not images. Switch to List to see them.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (others > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text('$others non-image file${others == 1 ? '' : 's'} shown in List view', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: images.length,
            itemBuilder: (context, i) {
              final f = images[i];
              final a = f.attachment;
              final downloading = ref.watch(attachmentDownloadsProvider).contains(a.id);
              return Tooltip(
                message: '${a.fileName}\n${f.senderLabel} · ${formatFileSize(a.size)} · ${relativeTime(f.date)}',
                child: Material(
                  key: ValueKey('photo-${a.id}'),
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppShapes.md),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: downloading ? null : () => openAttachment(context, ref, a),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LayoutBuilder(builder: (context, c) => AttachmentThumb(attachment: a, size: c.maxWidth, radius: 0)),
                        if (!f.isLocal && !downloading)
                          Positioned(right: 6, bottom: 6, child: Icon(Icons.cloud_download_outlined, size: 18, color: scheme.onSurfaceVariant)),
                        if (downloading) const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

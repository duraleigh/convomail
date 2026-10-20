import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../mail/mail_transport.dart';
import '../../../../store/database.dart';
import '../../../../sync/attachment_service.dart';
import '../../../theme/tokens.dart';
import 'attachment_preview.dart';

/// Icon, badge label, and color for a file type (spec 4.5: color-coded
/// badges for PDF, XLS, PPT, DOC, CSV, JPG, …).
class FileTypeStyle {
  const FileTypeStyle(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  static FileTypeStyle of(String mimeType, String fileName) {
    final mime = mimeType.toLowerCase();
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (mime.startsWith('image/')) return FileTypeStyle(Icons.image_outlined, ext.isEmpty ? 'IMG' : ext.toUpperCase(), const Color(0xFF2E7D32));
    if (mime == 'application/pdf' || ext == 'pdf') return const FileTypeStyle(Icons.picture_as_pdf_outlined, 'PDF', Color(0xFFC62828));
    if (mime.contains('spreadsheet') || mime.contains('excel') || ext == 'xlsx' || ext == 'xls') return const FileTypeStyle(Icons.table_chart_outlined, 'XLS', Color(0xFF1B5E20));
    if (mime == 'text/csv' || ext == 'csv') return const FileTypeStyle(Icons.table_rows_outlined, 'CSV', Color(0xFF00695C));
    if (mime.contains('presentation') || mime.contains('powerpoint') || ext == 'pptx' || ext == 'ppt') return const FileTypeStyle(Icons.slideshow_outlined, 'PPT', Color(0xFFD84315));
    if (mime.contains('word') || mime.contains('officedocument.wordprocessing') || ext == 'docx' || ext == 'doc') return const FileTypeStyle(Icons.description_outlined, 'DOC', Color(0xFF1565C0));
    if (mime.contains('zip') || mime.contains('compressed') || ext == 'zip' || ext == '7z' || ext == 'rar') return const FileTypeStyle(Icons.folder_zip_outlined, 'ZIP', Color(0xFF6A1B9A));
    if (mime.startsWith('audio/')) return const FileTypeStyle(Icons.audiotrack_outlined, 'AUDIO', Color(0xFF4527A0));
    if (mime.startsWith('video/')) return const FileTypeStyle(Icons.movie_outlined, 'VIDEO', Color(0xFF283593));
    if (mime.startsWith('text/') || ext == 'txt' || ext == 'md') return const FileTypeStyle(Icons.notes_outlined, 'TXT', Color(0xFF455A64));
    if (mime == 'text/calendar' || ext == 'ics') return const FileTypeStyle(Icons.event_outlined, 'ICS', Color(0xFF00838F));
    return FileTypeStyle(Icons.insert_drive_file_outlined, ext.isEmpty ? 'FILE' : ext.toUpperCase().substring(0, ext.length.clamp(0, 4)), const Color(0xFF546E7A));
  }
}

String formatFileSize(int bytes) {
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
  return '$bytes B';
}

bool canPreviewInApp(Attachment a) {
  final mime = a.mimeType.toLowerCase();
  final name = a.fileName.toLowerCase();
  if (mime.startsWith('image/') && !mime.contains('svg')) return true;
  if (mime == 'application/pdf' || name.endsWith('.pdf')) return true;
  return false;
}

/// Opens the in-app preview for images and PDFs, or hands anything else
/// to the OS. Downloads first when needed and reports failures inline.
Future<void> openAttachment(BuildContext context, WidgetRef ref, Attachment a) async {
  final service = ref.read(attachmentServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final path = await service.ensureLocal(a.id);
    if (!context.mounted) return;
    if (canPreviewInApp(a)) {
      await showAttachmentPreview(context, attachment: a, path: path);
    } else {
      await service.openWithSystem(a.id);
    }
  } on MailTransportException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating, width: 420));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not open ${a.fileName}: $e'), behavior: SnackBarBehavior.floating, width: 420));
  }
}

Future<void> saveAttachmentAs(BuildContext context, WidgetRef ref, Attachment a) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final path = await ref.read(attachmentServiceProvider).saveAs(a.id);
    if (path != null) messenger?.showSnackBar(SnackBar(content: Text('Saved ${a.fileName}'), behavior: SnackBarBehavior.floating, width: 360));
  } on MailTransportException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating, width: 420));
  }
}

/// Square thumbnail: the image itself once downloaded, otherwise the type
/// badge on a tonal surface.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({super.key, required this.attachment, this.size = 56, this.radius = AppShapes.md});
  final Attachment attachment;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = FileTypeStyle.of(attachment.mimeType, attachment.fileName);
    final local = attachment.localPath;
    final isImage = attachment.mimeType.toLowerCase().startsWith('image/') && !attachment.mimeType.toLowerCase().contains('svg');
    Widget child;
    if (isImage && local != null && File(local).existsSync()) {
      child = Image.file(File(local), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => _badge(style, scheme));
    } else {
      child = _badge(style, scheme);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: size, height: size, child: child));
  }

  Widget _badge(FileTypeStyle style, ColorScheme scheme) => Container(
        color: style.color.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.color, size: size * 0.42),
            if (size >= 48) Text(style.label, style: TextStyle(color: style.color, fontSize: size * 0.17, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      );
}

/// The attachment chip shown under a message (spec 4.3): tap to preview or
/// open, with a download spinner while fetching and a Save As action.
class AttachmentChip extends ConsumerWidget {
  const AttachmentChip({super.key, required this.attachment});
  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final downloading = ref.watch(attachmentDownloadsProvider).contains(attachment.id);
    final style = FileTypeStyle.of(attachment.mimeType, attachment.fileName);
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppShapes.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: downloading ? null : () => openAttachment(context, ref, attachment),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (downloading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(style.icon, size: 20, color: style.color),
              const SizedBox(width: 8),
              Text(attachment.fileName, style: text.labelLarge),
              const SizedBox(width: 8),
              Text(formatFileSize(attachment.size), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Save as…',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: downloading ? null : () => saveAttachmentAs(context, ref, attachment),
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

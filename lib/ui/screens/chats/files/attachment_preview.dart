import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../store/database.dart';
import '../../../../sync/attachment_service.dart';
import '../../../theme/tokens.dart';
import 'attachment_ui.dart';

/// In-app quick look for images and PDFs (spec 4.5), inside the main
/// window: a scrim, a card with the file name, Save As, Open with, and a
/// close button. Escape closes.
Future<void> showAttachmentPreview(BuildContext context, {required Attachment attachment, required String path}) {
  return showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
    builder: (_) => AttachmentPreviewDialog(attachment: attachment, path: path),
  );
}

class AttachmentPreviewDialog extends ConsumerWidget {
  const AttachmentPreviewDialog({super.key, required this.attachment, required this.path});
  final Attachment attachment;
  final String path;

  bool get _isPdf => attachment.mimeType.toLowerCase() == 'application/pdf' || attachment.fileName.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = FileTypeStyle.of(attachment.mimeType, attachment.fileName);
    final size = MediaQuery.sizeOf(context);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.all(32),
          backgroundColor: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.xl)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: size.width - 64,
            height: size.height - 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Icon(style.icon, color: style.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(attachment.fileName, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                            Text('${style.label} · ${formatFileSize(attachment.size)}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('preview-save-as'),
                        onPressed: () => saveAttachmentAs(context, ref, attachment),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Save as…'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => ref.read(attachmentServiceProvider).openWithSystem(attachment.id),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Open with…'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(tooltip: 'Close (Esc)', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: scheme.surfaceContainerLowest,
                    child: _isPdf
                        ? PdfViewer.file(
                            path,
                            params: PdfViewerParams(
                              backgroundColor: scheme.surfaceContainerLowest,
                              margin: 12,
                              errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
                                child: Text('Could not render this PDF ($error)', style: text.bodyMedium!.copyWith(color: scheme.error)),
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            maxScale: 6,
                            child: Center(
                              child: Image.file(
                                File(path),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Text('Could not decode this image.', style: text.bodyMedium!.copyWith(color: scheme.error)),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:drift/drift.dart';

import 'database.dart';

/// An attachment together with the message it came with, for the Files
/// panel (spec 4.5).
class RowAttachment {
  const RowAttachment({required this.attachment, required this.message});
  final Attachment attachment;
  final Message message;

  DateTime? get date => message.date ?? message.internalDate;
  String get senderLabel => message.isFromMe ? 'You' : (message.fromName.isNotEmpty ? message.fromName : message.fromAddress);
  bool get isImage => attachment.mimeType.toLowerCase().startsWith('image/');
  bool get isLocal => attachment.localPath != null;
}

/// A file anywhere in the mailbox, with the email it came with and the row
/// (chat or sender) that email sits in, for the Attachments page.
class FoundFile extends RowAttachment {
  const FoundFile({required super.attachment, required super.message, this.rowKey});
  final String? rowKey;

  /// From a person, or sent by the user (Chats); not from a list or a company (Feed).
  bool get fromPerson => message.isFromMe || message.classification != 'feeds';

  /// Everything a search looks through, in lower case.
  String get searchText => '${attachment.fileName} ${message.fromName} ${message.fromAddress} ${message.subject}${message.isFromMe ? ' you me' : ''}'.toLowerCase();
}

extension AttachmentQueries on AppDatabase {
  /// Every file that is not part of how an email looks, in every folder but
  /// junk, trash and drafts, newest first. An email kept in two folders
  /// gives its files once.
  Stream<List<FoundFile>> watchAllAttachments({int limit = 8000}) {
    final q = customSelect(
      '''
      SELECT a.id AS a_id, a.message_id AS a_message_id, a.part_id AS a_part_id, a.file_name AS a_file_name, a.mime_type AS a_mime_type,
             a.size AS a_size, a.content_id AS a_content_id, a.is_inline AS a_is_inline, a.local_path AS a_local_path,
             (SELECT MIN(r.row_key) FROM message_row_assignments r WHERE r.message_id = m.id) AS f_row_key,
             m.*
      FROM attachments a
      JOIN messages m ON m.id = a.message_id
      JOIN folders f ON f.id = m.folder_id
      WHERE a.is_inline = 0 AND m.is_deleted = 0 AND m.is_draft = 0 AND f.role NOT IN ('junk','trash','drafts')
      ORDER BY COALESCE(m.date, m.internal_date) DESC, a.id ASC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {attachments, messages, messageRowAssignments, folders},
    );
    return q.watch().map((rows) {
      final seen = <String>{};
      final out = <FoundFile>[];
      for (final r in rows) {
        final message = messages.map(r.data);
        final mid = message.messageId;
        if (mid != null && mid.isNotEmpty && !seen.add('$mid|${r.read<String>('a_part_id')}')) continue;
        out.add(FoundFile(
          attachment: Attachment(
            id: r.read<int>('a_id'),
            messageId: r.read<int>('a_message_id'),
            partId: r.read<String>('a_part_id'),
            fileName: r.read<String>('a_file_name'),
            mimeType: r.read<String>('a_mime_type'),
            size: r.read<int>('a_size'),
            contentId: r.readNullable<String>('a_content_id'),
            isInline: r.read<bool>('a_is_inline'),
            localPath: r.readNullable<String>('a_local_path'),
          ),
          message: message,
          rowKey: r.readNullable<String>('f_row_key'),
        ));
      }
      return out;
    });
  }

  /// Every non-inline attachment exchanged in a People-list row, newest
  /// first. Only messages whose body has been fetched have attachment rows;
  /// the Files panel fetches the rest on open.
  Stream<List<RowAttachment>> watchAttachmentsForRow(String rowKey) {
    final q = customSelect(
      '''
      SELECT a.id AS a_id, a.message_id AS a_message_id, a.part_id AS a_part_id, a.file_name AS a_file_name, a.mime_type AS a_mime_type,
             a.size AS a_size, a.content_id AS a_content_id, a.is_inline AS a_is_inline, a.local_path AS a_local_path,
             m.*
      FROM attachments a
      JOIN messages m ON m.id = a.message_id
      JOIN message_row_assignments r ON r.message_id = m.id
      JOIN folders f ON f.id = m.folder_id
      WHERE r.row_key = ? AND a.is_inline = 0 AND m.is_deleted = 0 AND f.role NOT IN ('junk','trash')
      ORDER BY COALESCE(m.date, m.internal_date) DESC, a.id ASC
      ''',
      variables: [Variable.withString(rowKey)],
      readsFrom: {attachments, messages, messageRowAssignments, folders},
    );
    return q.watch().map((rows) => [
          for (final r in rows)
            RowAttachment(
              attachment: Attachment(
                id: r.read<int>('a_id'),
                messageId: r.read<int>('a_message_id'),
                partId: r.read<String>('a_part_id'),
                fileName: r.read<String>('a_file_name'),
                mimeType: r.read<String>('a_mime_type'),
                size: r.read<int>('a_size'),
                contentId: r.readNullable<String>('a_content_id'),
                isInline: r.read<bool>('a_is_inline'),
                localPath: r.readNullable<String>('a_local_path'),
              ),
              message: messages.map(r.data),
            ),
        ]);
  }

  /// Messages in the row flagged as carrying attachments whose body (and
  /// therefore attachment list) has not been fetched yet.
  Future<List<Message>> rowMessagesNeedingAttachmentFetch(String rowKey) async {
    final rows = await customSelect(
      '''
      SELECT m.* FROM messages m
      JOIN message_row_assignments r ON r.message_id = m.id
      WHERE r.row_key = ? AND m.has_attachments = 1 AND m.body_fetched_at IS NULL AND m.attachments_listed_at IS NULL AND m.is_deleted = 0
      ORDER BY COALESCE(m.date, m.internal_date) DESC
      LIMIT 200
      ''',
      variables: [Variable.withString(rowKey)],
    ).get();
    return rows.map((r) => messages.map(r.data)).toList();
  }

  Future<Attachment?> attachmentById(int id) => (select(attachments)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<Attachment>> attachmentsForMessage(int messageId) => (select(attachments)..where((a) => a.messageId.equals(messageId))).get();

  Future<void> setAttachmentLocalPath(int id, String? path) => (update(attachments)..where((a) => a.id.equals(id))).write(AttachmentsCompanion(localPath: Value(path)));
}

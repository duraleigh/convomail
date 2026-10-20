import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mail/mail_transport.dart';
import '../store/attachment_queries.dart';
import '../store/attachment_store.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import 'sync_controller.dart';

/// Attachment ids currently being downloaded.
final attachmentDownloadsProvider = NotifierProvider<AttachmentDownloadsNotifier, Set<int>>(AttachmentDownloadsNotifier.new);

class AttachmentDownloadsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};
  void add(int id) => state = {...state, id};
  void remove(int id) => state = {...state}..remove(id);
}

final attachmentServiceProvider = Provider<AttachmentService>((ref) => AttachmentService(ref));

/// Downloads attachment bytes on demand, stores them locally, and hands
/// them to previews, Save As, or the OS (spec 4.5).
class AttachmentService {
  AttachmentService(this._ref);
  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  final Set<int> _inlineInFlight = {};

  /// Returns the local path, downloading first when needed.
  Future<String> ensureLocal(int attachmentId) async {
    final a = await _db.attachmentById(attachmentId);
    if (a == null) throw const MailTransportException('That attachment no longer exists.');
    if (a.localPath != null && File(a.localPath!).existsSync()) return a.localPath!;
    final downloads = _ref.read(attachmentDownloadsProvider.notifier);
    downloads.add(attachmentId);
    try {
      final paths = await _download(a.messageId, [a]);
      final path = paths[attachmentId];
      if (path == null) throw const MailTransportException('The server did not return that attachment.');
      return path;
    } finally {
      downloads.remove(attachmentId);
    }
  }

  /// Fetches every inline part of a message that is not yet on disk.
  Future<void> downloadInline(int messageId) async {
    if (!_inlineInFlight.add(messageId)) return;
    try {
      final missing = (await _db.attachmentsForMessage(messageId)).where((a) => a.isInline && a.localPath == null).toList();
      if (missing.isEmpty) return;
      await _download(messageId, missing);
    } catch (_) {
      // Rendering continues with placeholders; the chip retry path reports errors.
    } finally {
      _inlineInFlight.remove(messageId);
    }
  }

  Future<Map<int, String>> _download(int messageId, List<Attachment> targets) async {
    final m = await _db.messageById(messageId);
    if (m == null) throw const MailTransportException('That message no longer exists.');
    final syncer = _ref.read(syncControllerProvider).syncerFor(m.accountId);
    if (syncer == null) throw const MailTransportException('The account is not connected.');
    final bytes = await syncer.fetchParts(messageId, [for (final a in targets) a.partId]);
    final store = _ref.read(attachmentStoreProvider);
    final out = <int, String>{};
    for (final a in targets) {
      final data = bytes[a.partId];
      if (data == null) continue;
      final path = await store.save(accountId: m.accountId, messageId: messageId, partId: a.partId, fileName: a.fileName, bytes: data);
      await _db.setAttachmentLocalPath(a.id, path);
      out[a.id] = path;
    }
    return out;
  }

  /// Fetches bodies for the row's messages that are flagged as having
  /// attachments but whose attachment list is not known yet.
  Future<void> discoverForRow(String rowKey) async {
    final pending = await _db.rowMessagesNeedingAttachmentFetch(rowKey);
    for (final m in pending) {
      final syncer = _ref.read(syncControllerProvider).syncerFor(m.accountId);
      if (syncer == null) continue;
      try {
        await syncer.fetchBody(m.id);
      } catch (_) {
        break; // offline; the panel shows what is known
      }
    }
  }

  /// Save As dialog, then a copy of the local file. Returns the chosen path
  /// or null when cancelled.
  Future<String?> saveAs(int attachmentId) async {
    final a = await _db.attachmentById(attachmentId);
    if (a == null) return null;
    final src = await ensureLocal(attachmentId);
    final location = await getSaveLocation(suggestedName: AttachmentStore.safeFileName(a.fileName));
    if (location == null) return null;
    await File(src).copy(location.path);
    return location.path;
  }

  /// Hands the file to the system's default app for its type.
  Future<void> openWithSystem(int attachmentId) async {
    final path = await ensureLocal(attachmentId);
    await launchUrl(Uri.file(path));
  }

  /// `cid:` resolver for the sanitizer: downloaded inline parts become data
  /// URIs; unknown ones stay unresolved (and are blocked by the CSP).
  static String? dataUriFor(List<Attachment> inline, String cid) {
    final wanted = _normalizeCid(cid);
    for (final a in inline) {
      if (a.contentId == null || a.localPath == null) continue;
      if (_normalizeCid(a.contentId!) != wanted) continue;
      final f = File(a.localPath!);
      if (!f.existsSync()) continue;
      return 'data:${a.mimeType};base64,${base64Encode(f.readAsBytesSync())}';
    }
    return null;
  }

  static String _normalizeCid(String s) {
    var t = s.trim();
    if (t.toLowerCase().startsWith('cid:')) t = t.substring(4);
    if (t.startsWith('<') && t.endsWith('>')) t = t.substring(1, t.length - 1);
    return t.toLowerCase();
  }
}

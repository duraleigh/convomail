import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/signature.dart';
import '../store/attachment_queries.dart';
import '../store/compose_queries.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import 'attachment_service.dart';
import 'sync_controller.dart';

/// Where signature pictures are kept: copies, so a signature keeps working
/// when the original file moves.
final signatureImagesDirProvider = Provider<Future<Directory>>((ref) async {
  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'signature-images'));
  await dir.create(recursive: true);
  return dir;
});

final signatureServiceProvider = Provider<SignatureService>((ref) => SignatureService(ref));

enum GmailSignatureResult { imported, notFound, offline }

class SignatureService {
  SignatureService(this._ref);
  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Copies a picture into the signature folder and returns the copy's path.
  Future<String> keepPicture(String path) async {
    final bytes = await File(path).readAsBytes();
    return _save(bytes, p.extension(path));
  }

  Future<String> _save(List<int> bytes, String ext) async {
    final dir = await _ref.read(signatureImagesDirProvider);
    final name = '${sha1.convert(bytes).toString().substring(0, 16)}${ext.isEmpty ? '.img' : ext.toLowerCase()}';
    final file = File(p.join(dir.path, name));
    if (!file.existsSync()) await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Finds the Gmail signature in recent mail sent from [identity] and makes
  /// it the address's signature, pictures included.
  Future<GmailSignatureResult> importFromGmail(Identity identity) async {
    final sentFolders = await (_db.select(_db.folders)..where((f) => f.accountId.equals(identity.accountId) & f.role.equals('sent'))).get();
    if (sentFolders.isEmpty) return GmailSignatureResult.notFound;
    final candidates = await (_db.select(_db.messages)
          ..where((m) => m.folderId.isIn(sentFolders.map((f) => f.id)) & m.fromAddress.lower().equals(identity.email.toLowerCase()))
          ..orderBy([(m) => OrderingTerm.desc(m.internalDate)])
          ..limit(40))
        .get();
    final syncer = _ref.read(syncControllerProvider).syncerFor(identity.accountId);
    var offline = false;
    for (var m in candidates) {
      if (m.bodyFetchedAt == null) {
        if (syncer == null) {
          offline = true;
          continue;
        }
        try {
          await syncer.fetchBody(m.id);
          m = (await _db.messageById(m.id)) ?? m;
        } catch (_) {
          offline = true;
          continue;
        }
      }
      final html = m.bodyHtml;
      if (html == null) continue;
      final sigHtml = gmailSignatureHtml(html);
      if (sigHtml == null) continue;

      // Pictures: the message's own inline parts, or the web address Gmail
      // used. Both are kept as local copies.
      await _ref.read(attachmentServiceProvider).downloadInline(m.id);
      final inline = (await _db.attachmentsForMessage(m.id)).where((a) => a.isInline).toList();
      final pictures = <String, String>{};
      for (final src in RegExp(r'''<img[^>]+src\s*=\s*["']([^"']+)["']''', caseSensitive: false).allMatches(sigHtml).map((x) => x.group(1)!)) {
        final local = await _pictureFor(src, inline);
        if (local != null) pictures[src] = local;
      }
      final nodes = signatureNodesFromHtml(sigHtml, image: (src) => pictures[src]);
      if (nodes.isEmpty) continue;
      await saveSignature(identity.id, nodes);
      return GmailSignatureResult.imported;
    }
    return offline ? GmailSignatureResult.offline : GmailSignatureResult.notFound;
  }

  Future<String?> _pictureFor(String src, List<Attachment> inline) async {
    final lower = src.toLowerCase();
    if (lower.startsWith('cid:')) {
      final uri = AttachmentService.dataUriFor(inline, src);
      if (uri == null) return null;
      final comma = uri.indexOf(',');
      final mime = uri.substring(5, uri.indexOf(';'));
      return _save(base64Decode(uri.substring(comma + 1)), _extFor(mime));
    }
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final res = await (await client.getUrl(Uri.parse(src))).close().timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) return null;
        final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        return await _save(bytes, _extFor(res.headers.contentType?.mimeType ?? ''));
      } catch (_) {
        return null;
      } finally {
        client.close();
      }
    }
    return null;
  }

  static String _extFor(String mime) => switch (mime.toLowerCase()) {
        'image/gif' => '.gif',
        'image/png' => '.png',
        'image/jpeg' || 'image/jpg' => '.jpg',
        'image/webp' => '.webp',
        _ => '.img',
      };

  /// Stores [nodes] as the address's signature.
  Future<void> saveSignature(int identityId, List<Node> nodes) async {
    final trimmed = trimEmpty(nodes);
    if (trimmed.isEmpty) {
      await _db.setIdentitySignature(identityId, json: null, plainText: '');
      return;
    }
    final doc = Document.blank();
    for (final n in trimmed) {
      doc.root.insert(n.deepCopy());
    }
    await _db.setIdentitySignature(identityId, json: jsonEncode(doc.toJson()), plainText: nodesPlainText(trimmed));
  }
}

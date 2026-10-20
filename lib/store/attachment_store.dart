import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where downloaded attachment bytes live on disk (spec 4.5): one folder
/// per account and message under the app's support directory, so files
/// survive restarts and are removed with the account's cache.
class AttachmentStore {
  AttachmentStore(this._baseDir);

  final Future<Directory> Function() _baseDir;

  static Future<Directory> defaultBaseDir() async => Directory(p.join((await getApplicationSupportDirectory()).path, 'attachments'));

  Future<String> save({required int accountId, required int messageId, required String partId, required String fileName, required Uint8List bytes}) async {
    final dir = Directory(p.join((await _baseDir()).path, '$accountId', '$messageId'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${partId.replaceAll('.', '_')}_${safeFileName(fileName)}'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> removeForMessage(int accountId, int messageId) async {
    final dir = Directory(p.join((await _baseDir()).path, '$accountId', '$messageId'));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Strips path separators and characters Windows rejects in file names.
  static String safeFileName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (s.isEmpty || s == '.' || s == '..') s = 'attachment';
    return s.length > 150 ? s.substring(s.length - 150) : s;
  }
}

final attachmentStoreProvider = Provider<AttachmentStore>((ref) => AttachmentStore(AttachmentStore.defaultBaseDir));

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_log.dart';
import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../mail/outgoing.dart';
import '../store/compose_queries.dart';
import '../store/database.dart';
import 'schedule_service.dart';
import 'send_service.dart';

/// How many messages are waiting for a signal, for the line on Today.
final waitingSendCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(WaitingSends.key))).watchSingleOrNull().map((row) => WaitingSends.decode(row?.value).length);
});

/// Messages written with no signal. Each one waits here, in this device's
/// own notes, and is sent as soon as the mail server can be reached again:
/// nothing is lost, and nothing has to be pressed twice.
///
/// Only a send that never reached the mail server waits. One the server
/// refused (a wrong password, a refused recipient) is told to the user and
/// stays as a draft; it is never tried again by itself.
class WaitingSends {
  WaitingSends(this._ref);
  final Ref _ref;

  static const key = 'send.waiting';

  Timer? _timer;
  Future<void>? _sending;
  int _token = 0;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Call once the app is up.
  void start({Duration every = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(every, (_) => unawaited(sendNow()));
    unawaited(sendNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Keeps [s] to send later. Its draft is removed: the waiting copy is the
  /// message now, so it cannot be sent a second time from the draft.
  Future<void> keep(ComposeSubmission s) async {
    final list = decode(await _db.getSetting(key));
    list.add({
      'accountId': s.accountId,
      'identityId': s.identityId,
      'to': [for (final a in s.to) [a.address, a.name]],
      'cc': [for (final a in s.cc) [a.address, a.name]],
      'bcc': [for (final a in s.bcc) [a.address, a.name]],
      'subject': s.subject,
      'bodyHtml': s.bodyHtml,
      'attachments': [
        for (final a in s.attachments)
          {'fileName': a.fileName, 'mimeType': a.mimeType, 'path': a.path, 'contentId': a.contentId, if (a.bytes != null) 'bytes': base64Encode(a.bytes!)},
      ],
      'inReplyToMessageId': s.inReplyToMessageId,
      'kind': s.kind,
      'includeQuote': s.includeQuote,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await _db.putSetting(key, jsonEncode(list));
    if (s.draftId != null) await _db.deleteDraft(s.draftId!);
  }

  static List<Map<String, Object?>> decode(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return [for (final m in jsonDecode(json) as List) (m as Map).cast<String, Object?>()];
    } catch (_) {
      return [];
    }
  }

  static ComposeSubmission _submission(Map<String, Object?> m) {
    List<RemoteAddress> people(Object? v) => [for (final a in (v as List?) ?? const []) RemoteAddress('${(a as List)[0]}', '${a[1]}')];
    return ComposeSubmission(
      accountId: (m['accountId'] as num).toInt(),
      identityId: (m['identityId'] as num?)?.toInt(),
      to: people(m['to']),
      cc: people(m['cc']),
      bcc: people(m['bcc']),
      subject: '${m['subject'] ?? ''}',
      bodyHtml: '${m['bodyHtml'] ?? ''}',
      attachments: [
        for (final a in (m['attachments'] as List?) ?? const [])
          if (a is Map && (a['path'] != null || a['bytes'] != null))
            OutgoingAttachment(
              fileName: '${a['fileName']}',
              mimeType: '${a['mimeType']}',
              path: a['bytes'] != null ? null : a['path'] as String?,
              bytes: a['bytes'] is String ? base64Decode(a['bytes'] as String) : null,
              contentId: a['contentId'] as String?,
            ),
      ],
      inReplyToMessageId: (m['inReplyToMessageId'] as num?)?.toInt(),
      kind: '${m['kind'] ?? 'new'}',
      includeQuote: m['includeQuote'] != false,
    );
  }

  /// Tries to send what is waiting, oldest first. Stops at the first one
  /// that still cannot reach the server: there is still no signal.
  Future<void> sendNow() => _sending ??= _sendAll().whenComplete(() => _sending = null);

  Future<void> _sendAll() async {
    try {
      while (true) {
        final list = decode(await _db.getSetting(key));
        if (list.isEmpty) return;
        final first = list.first;
        final subject = '${first['subject'] ?? ''}';
        String? problem;
        try {
          await _ref.read(sendServiceProvider).send(_submission(first), token: 'waiting-${_token++}');
        } on MailTransportException catch (e) {
          if (e.offline) return;
          problem = e.message;
        } catch (e) {
          problem = '$e';
        }
        // Sent, or refused for good: either way it stops waiting. The list
        // is read again first, in case another message joined it meanwhile.
        final now = decode(await _db.getSetting(key));
        now.removeWhere((m) => m['at'] == first['at'] && m['subject'] == first['subject']);
        await _db.putSetting(key, jsonEncode(now));
        final notices = _ref.read(appNoticesProvider.notifier);
        if (problem == null) {
          notices.add(AppNotice(id: 'waiting-sent:${first['at']}', title: 'Sent', body: subject.isEmpty ? 'The message that was waiting for a signal.' : '“$subject”, which was waiting for a signal.', at: DateTime.now()));
        } else {
          // Refused: put it back among the drafts so nothing typed is lost.
          await _backToDraft(first);
          notices.add(AppNotice(id: 'waiting-failed:${first['at']}', title: 'Not sent', body: '${subject.isEmpty ? 'A message' : '“$subject”'} could not be sent: $problem It is back in your drafts.', at: DateTime.now()));
        }
      }
    } catch (e, st) {
      AppLog.current?.error('sending what was waiting failed', AppLog.scrub(e), st);
    }
  }

  Future<void> _backToDraft(Map<String, Object?> m) async {
    String people(Object? v) => AddressJson.encode([for (final a in (v as List?) ?? const []) RemoteAddress('${(a as List)[0]}', '${a[1]}')]);
    try {
      await _db.saveDraft(DraftsCompanion.insert(
        accountId: (m['accountId'] as num).toInt(),
        identityId: Value((m['identityId'] as num?)?.toInt()),
        kind: Value('${m['kind'] ?? 'new'}'),
        inReplyToMessageId: Value((m['inReplyToMessageId'] as num?)?.toInt()),
        recipientsTo: Value(people(m['to'])),
        recipientsCc: Value(people(m['cc'])),
        recipientsBcc: Value(people(m['bcc'])),
        subject: Value('${m['subject'] ?? ''}'),
        bodyHtml: Value('${m['bodyHtml'] ?? ''}'),
        includeQuote: Value(m['includeQuote'] != false),
      ));
    } catch (e, st) {
      AppLog.current?.error('putting a refused message back among the drafts failed', AppLog.scrub(e), st);
    }
  }
}

final waitingSendsProvider = Provider<WaitingSends>((ref) {
  final w = WaitingSends(ref);
  ref.onDispose(w.stop);
  return w;
});

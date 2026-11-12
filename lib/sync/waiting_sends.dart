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
import 'sent_sound.dart';

/// How many messages are on their way out, for the line on Today.
final waitingSendCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(WaitingSends.key))).watchSingleOrNull().map((row) => WaitingSends.decode(row?.value).length);
});

/// The last message that went out: who to, and a number that changes with
/// each one (the app says "Sent to …" once for each).
final lastSentProvider = NotifierProvider<LastSent, ({int n, String to})?>(LastSent.new);

class LastSent extends Notifier<({int n, String to})?> {
  @override
  ({int n, String to})? build() => null;
  void sent(String to) => state = (n: (state?.n ?? 0) + 1, to: to);
}

/// Every message being sent goes through here.
///
/// Pressing Send hands the message over and lets go at once: it is written
/// down in this device's own notes first, so nothing is lost if the app is
/// closed, and then sent in the background. The writing screen never waits
/// on the mail server.
///
/// With no signal the message simply waits and goes when the signal
/// returns. One the server refuses (a wrong password, a refused recipient)
/// is told to the user and put back among the drafts; it is never tried
/// again by itself.
class WaitingSends {
  WaitingSends(this._ref);
  final Ref _ref;

  static const key = 'send.waiting';

  Timer? _timer;
  Future<void>? _sending;
  bool _again = false;
  int _token = 0;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Call once the app is up.
  void start({Duration every = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(every, (_) => unawaited(sendNow()));
    unawaited(_afterRestart().then((_) => sendNow()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Takes a message to send and starts sending it right away. Returns as
  /// soon as it is written down.
  Future<void> submit(ComposeSubmission s, {String to = ''}) async {
    await keep(s, to: to);
    unawaited(sendNow());
  }

  /// Keeps [s] to send. Its draft is removed: the copy kept here is the
  /// message now, so it cannot be sent a second time from the draft.
  Future<void> keep(ComposeSubmission s, {String to = ''}) async {
    final list = decode(await _db.getSetting(key));
    // What the draft knew that the message itself does not: which chat it
    // belongs to, and the writing as the editor had it. Kept so that, should
    // the message come back, it comes back exactly where and as it was.
    final draft = s.draftId == null ? null : await _db.draftById(s.draftId!);
    list.add({
      'id': '${DateTime.now().microsecondsSinceEpoch}-${_token++}',
      'label': to,
      'rowKey': draft?.rowKey,
      'bodyJson': draft?.bodyJson,
      'attachmentsJson': draft?.attachmentsJson,
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

  static String _name(Map<String, Object?> m) {
    final label = '${m['label'] ?? ''}';
    if (label.isNotEmpty) return label;
    final to = (m['to'] as List?) ?? const [];
    if (to.isEmpty) return 'your recipients';
    final first = to.first as List;
    final name = '${first[1]}'.isEmpty ? '${first[0]}' : '${first[1]}';
    return to.length > 1 ? '$name +${to.length - 1}' : name;
  }

  /// A message that was in the middle of being sent when the app was
  /// closed may or may not have gone. It is never sent again by itself
  /// (that could send it twice): it goes back among the drafts, and the
  /// user is told to look in Sent.
  Future<void> _afterRestart() async {
    try {
      final list = decode(await _db.getSetting(key));
      final cut = [for (final m in list) if (m['trying'] != null) m];
      if (cut.isEmpty) return;
      list.removeWhere((m) => m['trying'] != null);
      await _db.putSetting(key, jsonEncode(list));
      for (final m in cut) {
        await _backToDraft(m);
        final subject = '${m['subject'] ?? ''}';
        _ref.read(appNoticesProvider.notifier).add(AppNotice(
              id: 'send-cut:${m['id']}',
              title: 'Check your Sent mail',
              body: 'Précis was closed while ${subject.isEmpty ? 'a message' : '“$subject”'} to ${_name(m)} was being sent. It is back in your drafts in case it did not go.',
              at: DateTime.now(),
            ));
      }
    } catch (e, st) {
      AppLog.current?.error('looking at what was being sent when the app closed failed', AppLog.scrub(e), st);
    }
  }

  /// Sends what is waiting, oldest first. Stops at the first one that
  /// cannot reach the server: there is no signal yet. A call made while
  /// one is running is followed by one more round, so a message handed
  /// over meanwhile is not left until the next tick.
  Future<void> sendNow() {
    final running = _sending;
    if (running != null) {
      _again = true;
      return running;
    }
    return _sending = () async {
      do {
        _again = false;
        await _sendAll();
      } while (_again);
    }()
        .whenComplete(() => _sending = null);
  }

  Future<void> _save(String id, Map<String, Object?>? Function(Map<String, Object?> item) change) async {
    final list = decode(await _db.getSetting(key));
    final out = <Map<String, Object?>>[];
    for (final m in list) {
      if (m['id'] == id) {
        final next = change(m);
        if (next != null) out.add(next);
      } else {
        out.add(m);
      }
    }
    await _db.putSetting(key, jsonEncode(out));
  }

  Future<void> _sendAll() async {
    try {
      final tried = <String>{};
      while (true) {
        final list = decode(await _db.getSetting(key));
        final first = list.where((m) => !tried.contains('${m['id']}')).firstOrNull;
        if (first == null) return;
        final id = '${first['id']}';
        tried.add(id);
        final subject = '${first['subject'] ?? ''}';
        String? problem;
        await _save(id, (m) => {...m, 'trying': DateTime.now().millisecondsSinceEpoch});
        final began = DateTime.now();
        AppLog.current?.info('send: starting');
        try {
          await _ref.read(sendServiceProvider).send(_submission(first), token: 'out-${_token++}', finishLater: true);
          AppLog.current?.info('send: the mail server took it after ${DateTime.now().difference(began).inMilliseconds} ms');
        } on MailTransportException catch (e) {
          AppLog.current?.warn('send: ${e.offline ? 'no signal' : 'refused'} after ${DateTime.now().difference(began).inMilliseconds} ms', AppLog.scrub(e.message));
          if (e.offline) {
            // No signal: it waits, untouched, for the next try.
            await _save(id, (m) => {...m}..remove('trying'));
            return;
          }
          problem = e.message;
        } catch (e) {
          problem = '$e';
        }
        await _save(id, (_) => null);
        if (problem == null) {
          _ref.read(lastSentProvider.notifier).sent(_name(first));
          unawaited(_ref.read(sentSoundProvider)());
        } else {
          // Refused: put it back among the drafts so nothing typed is lost.
          await _backToDraft(first);
          _ref.read(appNoticesProvider.notifier).add(AppNotice(
                id: 'send-failed:$id',
                title: 'Not sent',
                body: '${subject.isEmpty ? 'A message' : '“$subject”'} to ${_name(first)} could not be sent: $problem It is back in your drafts.',
                at: DateTime.now(),
              ));
        }
      }
    } catch (e, st) {
      AppLog.current?.error('sending failed in the background', AppLog.scrub(e), st);
    }
  }

  Future<void> _backToDraft(Map<String, Object?> m) async {
    String people(Object? v) => AddressJson.encode([for (final a in (v as List?) ?? const []) RemoteAddress('${(a as List)[0]}', '${a[1]}')]);
    try {
      await _db.saveDraft(DraftsCompanion.insert(
        accountId: (m['accountId'] as num).toInt(),
        identityId: Value((m['identityId'] as num?)?.toInt()),
        kind: Value('${m['kind'] ?? 'new'}'),
        rowKey: Value(m['rowKey'] as String?),
        bodyJson: Value(m['bodyJson'] as String?),
        attachmentsJson: Value((m['attachmentsJson'] as String?) ?? '[]'),
        inReplyToMessageId: Value((m['inReplyToMessageId'] as num?)?.toInt()),
        recipientsTo: Value(people(m['to'])),
        recipientsCc: Value(people(m['cc'])),
        recipientsBcc: Value(people(m['bcc'])),
        subject: Value('${m['subject'] ?? ''}'),
        bodyHtml: Value('${m['bodyHtml'] ?? ''}'),
        includeQuote: Value(m['includeQuote'] != false),
      ));
    } catch (e, st) {
      AppLog.current?.error('putting a message back among the drafts failed', AppLog.scrub(e), st);
    }
  }
}

final waitingSendsProvider = Provider<WaitingSends>((ref) {
  final w = WaitingSends(ref);
  ref.onDispose(w.stop);
  return w;
});

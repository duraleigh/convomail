import 'dart:io';
import 'dart:typed_data';

import 'package:convomail/mail/models.dart';
import 'package:convomail/store/attachment_queries.dart';
import 'package:convomail/store/attachment_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Opening an email shows it at once: its words are fetched ahead of time,
/// in the background, instead of when it is clicked.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;
  late Directory dir;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  int got(String subject, DateTime at, {String? id, int size = 4000, RemoteMessageBody? body}) => imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [me], subject: subject, messageId: id, date: at, size: size),
        body: body ?? RemoteMessageBody(text: 'Words of $subject'),
      );

  Future<AccountSyncer> sync({Duration wordsAheadFor = const Duration(days: 30), int maxSize = 5000000}) async {
    final syncer = AccountSyncer(
      db: db,
      transport: imap,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
      attachmentStore: AttachmentStore(() async => dir),
      wordsAheadFor: wordsAheadFor,
      wordsAheadMaxSize: maxSize,
    );
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  Future<Message> mail(String subject) async => (await db.select(db.messages).get()).firstWhere((m) => m.subject == subject);

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    dir = await Directory.systemTemp.createTemp('precis-words-ahead');
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('the words of recent emails are fetched before anyone opens them, newest first, a few at a time', () async {
    got('Monday', ago(days: 3));
    got('Tuesday', ago(days: 2));
    got('Wednesday', ago(days: 1));
    got('Long ago', ago(days: 60));
    final syncer = await sync();
    expect((await mail('Wednesday')).bodyFetchedAt, isNull, reason: 'checking for mail brings the list, not the words');

    expect(await syncer.readWordsAhead(batch: 2), 2);
    expect((await mail('Wednesday')).bodyFetchedAt, isNotNull);
    expect((await mail('Tuesday')).bodyFetchedAt, isNotNull);
    expect((await mail('Monday')).bodyFetchedAt, isNull, reason: 'the next batch');
    expect(await syncer.readWordsAhead(batch: 2), 1);
    expect((await mail('Monday')).bodyText, 'Words of Monday');
    expect(await syncer.readWordsAhead(batch: 2), 0, reason: 'nothing left');
    expect((await mail('Long ago')).bodyFetchedAt, isNull, reason: 'old mail is fetched when it is opened');
    expect((await mail('Wednesday')).isSeen, isFalse, reason: 'fetching ahead does not mark anything read');
  });

  test('what is in Focus goes first, however old it is; a very large email waits until it is opened', () async {
    got('Recent', ago(days: 1));
    got('Old but needs you', ago(days: 45), id: '<needs@x>');
    got('Huge', ago(hours: 2), size: 9000000);
    final syncer = await sync();
    await db.applyingFromHelper(() => db.applyHelperItem('read', '<needs@x>', {'line': 'Sarah needs an answer.', 'focus': true, 'ask': 'Answer Sarah.', 'why': <String>[], 'answered': false, 'at': 1}, deleted: false));

    expect(await syncer.readWordsAhead(batch: 1), 1);
    expect((await mail('Old but needs you')).bodyFetchedAt, isNotNull, reason: 'Focus first');
    expect((await mail('Recent')).bodyFetchedAt, isNull);
    expect(await syncer.readWordsAhead(), 1);
    expect((await mail('Recent')).bodyFetchedAt, isNotNull);
    expect((await mail('Huge')).bodyFetchedAt, isNull);
  });

  test('a phone fetches less: fewer days back, and smaller emails only', () async {
    got('Yesterday', ago(days: 1));
    got('Two weeks ago', ago(days: 14));
    got('Big', ago(days: 1), size: 2000000);
    final syncer = await sync(wordsAheadFor: const Duration(days: 7), maxSize: 1500000);
    expect(await syncer.readWordsAhead(), 1);
    expect((await mail('Yesterday')).bodyFetchedAt, isNotNull);
    expect((await mail('Two weeks ago')).bodyFetchedAt, isNull);
    expect((await mail('Big')).bodyFetchedAt, isNull);
  });

  test('pictures that sit inside an email come with it, so it is drawn once, whole', () async {
    final png = Uint8List.fromList(List<int>.generate(70, (i) => i));
    final uid = got(
      'With a logo',
      ago(days: 1),
      body: const RemoteMessageBody(
        html: '<p>Hello</p><img src="cid:logo@x.com">',
        attachments: [RemoteAttachment(partId: '1.2', fileName: 'logo.png', mimeType: 'image/png', size: 70, contentId: '<logo@x.com>', isInline: true)],
      ),
    );
    imap.folder('INBOX').parts[uid] = {'1.2': png};
    final syncer = await sync();
    expect(await syncer.readWordsAhead(), 1);
    final m = await mail('With a logo');
    final picture = (await db.attachmentsForMessage(m.id)).single;
    expect(picture.isInline, isTrue);
    expect(picture.localPath, isNotNull, reason: 'already on this device');
    expect(File(picture.localPath!).readAsBytesSync(), png);
  });

  test('a connection that died while it sat quiet is found out with a quick check and replaced, so a click never waits on it', () async {
    for (final s in ['One', 'Two', 'Three', 'Four']) {
      got(s, ago(days: 1));
    }
    var now = DateTime(2026, 11, 12, 9);
    final line = imap.secondConnection();
    final syncer = AccountSyncer(
      db: db,
      transport: imap,
      onDemandTransport: line,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
      clock: () => now,
    );
    await syncer.syncOnce();

    await syncer.fetchBody((await mail('One')).id);
    expect(line.connectCount, 1);
    // Used again right away: no need to check.
    await syncer.fetchBody((await mail('Two')).id);
    expect(line.pingCount, 0);
    // Quiet for a minute and still alive: checked, kept.
    now = now.add(const Duration(minutes: 1));
    await syncer.fetchBody((await mail('Three')).id);
    expect(line.pingCount, 1);
    expect(line.connectCount, 1);
    // Quiet for a minute and dead (the laptop slept): checked, replaced, and the email still opens.
    now = now.add(const Duration(minutes: 1));
    line.deadLine = true;
    await syncer.fetchBody((await mail('Four')).id);
    expect(line.pingCount, 2);
    expect(line.connectCount, 2, reason: 'a fresh connection');
    expect((await mail('Four')).bodyText, 'Words of Four');
  });

  test('an email that cannot be fetched is tried once, not over and over; the rest still come', () async {
    got('First', ago(days: 2));
    got('Second', ago(days: 1));
    final syncer = await sync();
    imap.failFetchBody = 1;
    expect(await syncer.readWordsAhead(), 1);
    expect((await mail('Second')).bodyFetchedAt, isNull, reason: 'the newest one failed');
    expect((await mail('First')).bodyFetchedAt, isNotNull);
    expect(await syncer.readWordsAhead(), 0, reason: 'not tried again in this run');
  });
}

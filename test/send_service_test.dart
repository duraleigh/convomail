import 'dart:convert';
import 'dart:typed_data';

import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/outgoing.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/send_service.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:enough_mail/enough_mail.dart' show ContentDisposition;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// SendService end to end against a recording SMTP sender and the fake IMAP
/// server: MIME content, Sent-copy handling per provider, the answered
/// flag, draft cleanup, failure reporting, and filing into the recipient's
/// row after the Sent sync.
void main() {
  late AppDatabase db;
  late FakeMailTransport imap;
  late RecordingMailSender smtp;
  late ProviderContainer container;
  late Account account;
  late int sarahMsg;

  Future<void> setUpWith({String providerId = 'custom'}) async {
    db = testDatabase();
    imap = FakeMailTransport();
    smtp = RecordingMailSender();
    final store = InMemoryCredentialStore();
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => store),
      transportFactoryProvider.overrideWith((ref) => () => imap),
      mailSenderProvider.overrideWith((ref) => smtp),
    ]);
    account = await insertTestAccount(db);
    if (providerId != 'custom') {
      await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(AccountsCompanion(providerId: Value(providerId)));
      account = (await db.accountById(account.id))!;
    }
    await store.write(CredentialStore.passwordKey(account.id), 'secret');
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), signature: const Value('Best,\nClay'), isDefault: const Value(true)));

    // Server: INBOX with one message from Sarah, an empty Sent folder.
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    inbox.add(
      RemoteMessageHeader(
        uid: 0,
        from: const RemoteAddress('sarah@x.com', 'Sarah Chen'),
        to: const [RemoteAddress('me@example.com')],
        subject: 'Figma access',
        messageId: '<orig@x.com>',
        date: DateTime(2026, 9, 28, 10),
      ),
      body: const RemoteMessageBody(html: '<p>Can you add me to the <b>Figma</b> team?</p>'),
    );
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    container.read(syncControllerProvider).adoptForTest(account.id, syncer);
    await db.refreshDirtyRows();
    sarahMsg = (await db.messagesForRow('c:sarah@x.com')).single.id;
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('reply: SMTP gets the MIME, custom server gets an APPEND to Sent, original is answered, draft deleted, message files under Sarah', () async {
    await setUpWith();
    final draftId = await db.saveDraft(DraftsCompanion(accountId: Value(account.id), kind: const Value('reply'), rowKey: const Value('c:sarah@x.com'), subject: const Value('Re: Figma access')));
    final id = await container.read(sendServiceProvider).send(
          ComposeSubmission(
            accountId: account.id,
            identityId: (await db.identitiesForAccount(account.id)).single.id,
            to: const [RemoteAddress('sarah@x.com', 'Sarah Chen')],
            subject: 'Re: Figma access',
            bodyHtml: '<p>Done!</p>',
            inReplyToMessageId: sarahMsg,
            kind: 'reply',
            draftId: draftId,
          ),
          token: 't',
        );

    // SMTP.
    expect(smtp.sent, hasLength(1));
    final rec = smtp.sent.single;
    expect(rec.server.host, 'smtp.example.com');
    expect(rec.server.port, 465);
    expect(rec.username, 'me@example.com');
    expect(rec.recipients.map((r) => r.address), ['sarah@x.com']);
    final parsed = rec.parsed;
    expect(parsed.getHeaderValue('in-reply-to'), '<orig@x.com>');
    expect(parsed.getHeaderValue('references'), '<orig@x.com>');
    expect(parsed.getHeaderValue('message-id'), id);
    final html = parsed.decodeTextHtmlPart()!;
    expect(html, contains('<p>Done!</p>'));
    expect(html, contains('Sarah Chen &lt;sarah@x.com&gt; wrote:'));
    expect(html, contains('<blockquote'));
    expect(html, contains('<b>Figma</b>'));
    expect(parsed.decodeTextPlainPart(), contains('> Can you add me to the Figma team?'));

    // Sent copy appended (custom provider) and synced back.
    expect(imap.appended, hasLength(1));
    expect(imap.appended.single.$1, 'Sent');
    final sarahRow = await db.messagesForRow('c:sarah@x.com');
    expect(sarahRow, hasLength(2), reason: 'my reply files under the recipient');
    final mine = sarahRow.firstWhere((m) => m.isFromMe);
    expect(mine.subject, 'Re: Figma access');
    expect(mine.threadKey, isNotNull);
    expect(mine.threadKey, (await db.messageById(sarahMsg))!.threadKey, reason: 'same thread via In-Reply-To');

    // Original marked answered locally and on the server.
    expect((await db.messageById(sarahMsg))!.isAnswered, isTrue);
    expect(imap.folder('INBOX').messages.values.single.flags.answered, isTrue);

    // Draft gone, progress done.
    expect(await db.draftById(draftId), isNull);
    expect(container.read(sendProgressProvider)['t']!.phase, SendPhase.done);
  });

  test('gmail: no APPEND because the server files the copy; Sent is still re-synced', () async {
    await setUpWith(providerId: 'gmail');
    await container.read(sendServiceProvider).send(
          ComposeSubmission(accountId: account.id, identityId: null, to: const [RemoteAddress('sarah@x.com')], subject: 'Hi', bodyHtml: '<p>x</p>'),
          token: 't',
        );
    expect(smtp.sent, hasLength(1));
    expect(imap.appended, isEmpty);
    expect(imap.log.where((l) => l.startsWith('select Sent')), isNotEmpty, reason: 'Sent folder re-synced after the send');
  });

  test('forward includes the forwarded header block and no In-Reply-To', () async {
    await setUpWith();
    await container.read(sendServiceProvider).send(
          ComposeSubmission(accountId: account.id, identityId: null, to: const [RemoteAddress('tom@x.com')], subject: 'Fwd: Figma access', bodyHtml: '<p>FYI</p>', inReplyToMessageId: sarahMsg, kind: 'forward'),
          token: 't',
        );
    final m = smtp.sent.single.parsed;
    expect(m.getHeaderValue('in-reply-to'), isNull);
    final html = m.decodeTextHtmlPart()!;
    expect(html, contains('Forwarded message'));
    expect(html, contains('From: Sarah Chen &lt;sarah@x.com&gt;'));
    expect(html, contains('Subject: Figma access'));
    expect((await db.messageById(sarahMsg))!.isAnswered, isFalse);
  });

  test('a rejected send reports the error, keeps the draft, and appends nothing', () async {
    await setUpWith();
    smtp.failWith = const MailTransportException('The mail server rejected the username or password.', isAuthFailure: true);
    final draftId = await db.saveDraft(DraftsCompanion(accountId: Value(account.id), subject: const Value('x')));
    await expectLater(
      container.read(sendServiceProvider).send(
            ComposeSubmission(accountId: account.id, identityId: null, to: const [RemoteAddress('sarah@x.com')], subject: 'x', bodyHtml: '<p>x</p>', draftId: draftId),
            token: 't',
          ),
      throwsA(isA<MailTransportException>()),
    );
    final p = container.read(sendProgressProvider)['t']!;
    expect(p.phase, SendPhase.failed);
    expect(p.error, contains('rejected'));
    expect(await db.draftById(draftId), isNotNull);
    expect(imap.appended, isEmpty);
  });

  test('derivedSubject adds Re:/Fwd: once', () async {
    await setUpWith();
    final m = (await db.messageById(sarahMsg))!;
    expect(SendService.derivedSubject(m, forward: false), 'Re: Figma access');
    expect(SendService.derivedSubject(m, forward: true), 'Fwd: Figma access');
    final re = m.copyWith(subject: 'RE: Figma access');
    expect(SendService.derivedSubject(re, forward: false), 'RE: Figma access');
    expect(SendService.derivedSubject(re, forward: true), 'Fwd: RE: Figma access');
  });

  test('attachments travel with the send', () async {
    await setUpWith();
    await container.read(sendServiceProvider).send(
          ComposeSubmission(
            accountId: account.id,
            identityId: null,
            to: const [RemoteAddress('sarah@x.com')],
            subject: 'Bytes',
            bodyHtml: '<p>x</p>',
            attachments: [OutgoingAttachment(fileName: 'hello.txt', mimeType: 'text/plain', bytes: Uint8List.fromList(utf8.encode('hi')))],
          ),
          token: 't',
        );
    final m = smtp.sent.single.parsed;
    expect(m.findContentInfo(disposition: ContentDisposition.attachment).single.fileName, 'hello.txt');
  });
}

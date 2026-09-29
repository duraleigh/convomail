import 'package:convomail/domain/filing.dart';
import 'package:convomail/domain/identity.dart';
import 'package:convomail/mail/provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAddress', () {
    test('lower-cases, trims, strips brackets', () {
      expect(normalizeAddress('  <Sarah.Chen@Example.COM> '), 'sarah.chen@example.com');
    });
    test('gmail dots and plus tags collapse; googlemail maps to gmail', () {
      expect(normalizeAddress('Si.mon+work@gmail.com'), 'simon@gmail.com');
      expect(normalizeAddress('simon@googlemail.com'), 'simon@gmail.com');
      expect(normalizeAddress('si.mon@example.com'), 'si.mon@example.com');
    });
  });

  group('IdentityResolver (spec 4.14, decision 8)', () {
    final r = IdentityResolver(
      myAddresses: ['Me@Example.com', 'me.alias+x@gmail.com'],
      addressToContact: {'sarah@work.com': 'sarah@home.com'},
    );

    test('all my aliases resolve to me', () {
      expect(r.resolve('me@example.com').contactKey, IdentityResolver.me);
      expect(r.resolve('mealias@gmail.com').isMe, isTrue);
      expect(r.isMe('ME@EXAMPLE.COM'), isTrue);
    });

    test("a contact's several addresses resolve to one key", () {
      expect(r.contactKeyFor('Sarah@Work.com'), 'sarah@home.com');
      expect(r.contactKeyFor('sarah@home.com'), 'sarah@home.com');
      expect(r.contactKeyFor('joann@example.com'), 'joann@example.com');
    });

    test('participantKeys excludes me and dedupes', () {
      expect(r.participantKeys(['me@example.com', 'sarah@work.com', 'sarah@home.com', 'simon@x.com']), {'sarah@home.com', 'simon@x.com'});
    });
  });

  group('FilingRule (spec 4.3/4.19, decisions 1, 5, 6)', () {
    final identity = IdentityResolver(myAddresses: ['me@example.com']);
    final simonJoann = GroupDefinition(id: 7, memberKeys: ['simon@x.com', 'joann@x.com']);
    final rule = FilingRule(identity, groups: [simonJoann]);

    test('received mail files under the sender only', () {
      final f = rule.file(const MessageEnvelope(from: 'simon@x.com', to: ['me@example.com', 'sarah@x.com', 'joann@x.com']));
      expect(f.rows, {const ContactRow('simon@x.com')});
      expect(f.isFromMe, isFalse);
      expect(f.participantKeys, {'simon@x.com', 'sarah@x.com', 'joann@x.com'});
    });

    test("Sarah's reply files under Sarah, not Simon or Joann", () {
      final f = rule.file(const MessageEnvelope(from: 'sarah@x.com', to: ['simon@x.com', 'me@example.com'], cc: ['joann@x.com']));
      expect(f.rows, {const ContactRow('sarah@x.com')});
    });

    test('sent mail files under each recipient', () {
      final f = rule.file(const MessageEnvelope(from: 'me@example.com', to: ['sarah@x.com'], cc: ['tom@x.com']));
      expect(f.rows, {const ContactRow('sarah@x.com'), const ContactRow('tom@x.com')});
      expect(f.isFromMe, isTrue);
    });

    test('mail to only myself files under me', () {
      final f = rule.file(const MessageEnvelope(from: 'me@example.com', to: ['me@example.com']));
      expect(f.rows, {const ContactRow(IdentityResolver.me)});
    });

    test('exact group match files in the group row only', () {
      final f = rule.file(const MessageEnvelope(from: 'simon@x.com', to: ['me@example.com', 'joann@x.com']));
      expect(f.rows, {const GroupRow(7)});
    });

    test('a group match applies to sent mail too', () {
      final f = rule.file(const MessageEnvelope(from: 'me@example.com', to: ['simon@x.com', 'joann@x.com']));
      expect(f.rows, {const GroupRow(7)});
    });

    test('one extra participant breaks the match and falls back to sender-only', () {
      final f = rule.file(const MessageEnvelope(from: 'joann@x.com', to: ['me@example.com', 'simon@x.com', 'sarah@x.com']));
      expect(f.rows, {const ContactRow('joann@x.com')});
    });

    test('one missing member breaks the match', () {
      final f = rule.file(const MessageEnvelope(from: 'simon@x.com', to: ['me@example.com']));
      expect(f.rows, {const ContactRow('simon@x.com')});
    });

    test('CC counts as a participant (decision 3)', () {
      final f = rule.file(const MessageEnvelope(from: 'simon@x.com', to: ['me@example.com'], cc: ['joann@x.com']));
      expect(f.rows, {const GroupRow(7)});
    });

    test('row keys round-trip', () {
      expect(RowRef.parse('c:sarah@x.com'), const ContactRow('sarah@x.com'));
      expect(RowRef.parse('g:7'), const GroupRow(7));
    });
  });

  group('ProviderProfiles', () {
    test('gmail resolves to bundled profile with app-password help', () {
      final p = ProviderProfiles.forEmail('someone@gmail.com')!;
      expect(p.id, 'gmail');
      expect(p.imap.host, 'imap.gmail.com');
      expect(p.imap.port, 993);
      expect(p.appPasswordUrl, isNotNull);
    });
    test('unknown domains get guesses, no network', () {
      expect(ProviderProfiles.forEmail('a@corp.example'), isNull);
      final g = ProviderProfiles.guessImap('corp.example');
      expect(g.first.host, 'imap.corp.example');
      expect(g.map((s) => s.port).toSet(), {993, 143});
    });
  });
}

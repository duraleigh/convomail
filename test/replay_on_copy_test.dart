import 'dart:io';

import 'package:convomail/store/database.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-off: times what a device does when the helper tells it again what it
/// already knows (every sender, every email's place, every reading), on a
/// private copy of the real data. Prints counts and seconds only. Not part
/// of the app's checks (needs PRECIS_COPY).
void main() {
  final path = Platform.environment['PRECIS_COPY'];
  test('taking in again what is already known', () async {
    final db = AppDatabase(NativeDatabase(File(path!)));
    addTearDown(db.close);
    final service = ClassificationService(db);
    final senders = await db.customSelect("SELECT key, classification, classification_source, feeds_category, class_reasons FROM contacts WHERE is_me = 0").get();
    final sorts = await db.select(db.helperVerdicts).get();
    final reads = await db.select(db.helperReadings).get();
    // The same in pages of 500, as the helper hands them over.
    Future<int> timed(Future<void> Function() work) async {
      final t = Stopwatch()..start();
      await work();
      return t.elapsedMilliseconds;
    }

    // Once first, so everything is as the helper says; then the timed pass
    // is purely "told again what is already known".
    Future<int> pass() async {
      var refiled = 0;
      for (var at = 0; at < senders.length; at += 500) {
        final refile = <String>{};
        await db.applyingFromHelper(() async {
          for (final s in senders.skip(at).take(500)) {
            refile.addAll(await db.applyHelperItem('sender', s.read<String>('key'), {
              'cls': s.read<String>('classification') == 'feeds' ? 'feeds' : 'people',
              'src': s.read<String>('classification_source'),
              'cat': s.readNullable<String>('feeds_category'),
              'reasons': s.read<String>('class_reasons'),
            }, deleted: false));
          }
        });
        refiled += refile.length;
        if (refile.isNotEmpty) await service.classifySenders(refile, log: false);
        await db.refreshDirtyRows();
      }
      for (var at = 0; at < sorts.length; at += 500) {
        await db.applyingFromHelper(() async {
          for (final v in sorts.skip(at).take(500)) {
            await db.applyHelperItem('sort', v.messageId, {'cls': v.cls, 'cat': v.cat, 'pile': v.pile}, deleted: false);
          }
        });
        await db.refreshDirtyRows();
      }
      for (var at = 0; at < reads.length; at += 500) {
        await db.applyingFromHelper(() async {
          for (final r in reads.skip(at).take(500)) {
            await db.applyHelperItem('read', r.messageId, {
              'line': r.line, 'focus': r.focus, 'ask': r.ask, 'due': r.due == null ? null : r.due!.millisecondsSinceEpoch ~/ 1000, 'why': const <String>[],
              'answered': r.answered, 'at': r.readAt == null ? null : r.readAt!.millisecondsSinceEpoch ~/ 1000, 'sent': r.sent, 'asks': r.asks, 'know': r.know, 'thing': r.thing, 'draft': r.draft,
            }, deleted: false);
          }
        });
      }
      return refiled;
    }

    final first = await timed(pass);
    late int refiled;
    final again = await timed(() async => refiled = await pass());
    // ignore: avoid_print
    print('senders ${senders.length} | places of emails ${sorts.length} | readings ${reads.length}');
    // ignore: avoid_print
    print('first pass ${(first / 1000).toStringAsFixed(1)} s | told again what is already known: ${(again / 1000).toStringAsFixed(1)} s, senders filed again: $refiled');
  }, skip: path == null ? 'no copy given' : false, timeout: const Timeout(Duration(minutes: 20)));
}

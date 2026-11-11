import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The messages that pop up at the bottom of the window go away by
/// themselves, and none stays longer than ten seconds.
void main() {
  test('every pop-up message in the app is set to leave by itself, within ten seconds', () {
    final call = RegExp(r'(?<![A-Za-z])SnackBar\(');
    var found = 0;
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final m in call.allMatches(s)) {
        found++;
        // The whole call, up to its closing bracket.
        var depth = 1;
        var j = m.end;
        while (j < s.length && depth > 0) {
          if (s[j] == '(') depth++;
          if (s[j] == ')') depth--;
          j++;
        }
        final body = s.substring(m.end, j);
        final where = '${f.path} near "${body.length > 60 ? body.substring(0, 60) : body}"';
        // Without this, a message with a button (such as Undo) stays until it is dismissed by hand.
        expect(body, contains('persist: false'), reason: where);
        for (final d in RegExp(r'duration:\s*(?:const\s+)?Duration\(seconds:\s*(\d+)\)').allMatches(body)) {
          expect(int.parse(d.group(1)!), lessThanOrEqualTo(10), reason: where);
        }
        expect(RegExp(r'duration:\s*(?:const\s+)?Duration\(minutes').hasMatch(body), isFalse, reason: where);
      }
    }
    expect(found, greaterThan(10), reason: 'the scan should have found the app\'s messages');
  });

  testWidgets('a message with an Undo button leaves by itself when its time is up', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              persist: false,
              duration: const Duration(seconds: 8),
              content: const Text('Archived 3 emails'),
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Archived 3 emails'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.text('Archived 3 emails'), findsNothing, reason: 'gone within ten seconds, without a click');
  });
}

import 'package:appflowy_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor keeps the cursor in view by scrolling to it. On a phone it
/// does so with no time between steps. In a writing area shorter than the
/// space it keeps clear around the cursor it used to step down, then up,
/// then down, for ever, without letting the app draw again: the app stopped
/// responding ("Précis isn't responding" when replying with the keyboard up
/// and many people in To and Cc).
void main() {
  Future<ScrollableState> area(WidgetTester tester, double height) async {
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: height,
          width: 300,
          child: ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 30, child: Text('line $i'))]),
        ),
      ),
    ));
    return tester.state<ScrollableState>(find.byType(Scrollable));
  }

  for (final height in [0.0, 12.0, 60.0]) {
    testWidgets('a writing area $height high: bringing the cursor into view ends', (tester) async {
      final scrollable = await area(tester, height);
      scrollable.position.jumpTo(300);
      await tester.pump();
      final scroller = AutoScroller(scrollable);
      // The cursor is on screen at the area's own place; the space kept clear around it is taller than the area.
      scroller.startAutoScroll(Offset(10, height / 2), edgeOffset: 100, duration: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scroller.scrolling, isFalse, reason: 'it came to rest');
      expect(scrollable.position.pixels, inInclusiveRange(250.0, 350.0), reason: 'the cursor was already in view: the page hardly moves');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a cursor below a roomy writing area is still brought into view', (tester) async {
    final scrollable = await area(tester, 400);
    final scroller = AutoScroller(scrollable);
    scroller.startAutoScroll(const Offset(10, 395), edgeOffset: 100, duration: Duration.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(scroller.scrolling, isFalse);
    expect(scrollable.position.pixels, greaterThan(20), reason: 'it moved down to clear room under the cursor');
  });
}

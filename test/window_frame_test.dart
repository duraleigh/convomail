import 'package:convomail/ui/shell/window_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app sits inside a see-through frame, deeper at the top', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('window_manager');
    messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'isMaximized' ? false : null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: WindowFrame(child: ColoredBox(key: ValueKey('app'), color: Colors.white))));

    final app = tester.getRect(find.byKey(const ValueKey('app')));
    expect(app.left, windowFrameEdge);
    expect(app.right, 1000 - windowFrameEdge);
    expect(app.bottom, 700 - windowFrameEdge);
    expect(app.top, windowBarHeight);
    expect(windowBarHeight, greaterThan(windowFrameEdge));

    // The window buttons stay hidden until the pointer is over them.
    double buttonsOpacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: find.byKey(const ValueKey('window-close')), matching: find.byType(AnimatedOpacity))).opacity;
    expect(buttonsOpacity(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('window-maximize'))));
    await tester.pumpAndSettle();
    expect(buttonsOpacity(), 1);
  });
}

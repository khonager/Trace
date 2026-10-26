import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/presentation/typing_bubble.dart';

void main() {
  testWidgets('typing bubble animates and respects reduced motion', (
    tester,
  ) async {
    Widget app(bool reduce) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Scaffold(body: TypingBubble(label: 'Alice is typing…')),
      ),
    );
    await tester.pumpWidget(app(false));
    final before = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform;
    await tester.pump(const Duration(milliseconds: 200));
    final after = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform;
    expect(after, isNot(before));
    expect(find.bySemanticsLabel('Alice is typing…'), findsOneWidget);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

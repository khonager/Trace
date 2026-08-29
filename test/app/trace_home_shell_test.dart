import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/trace_app.dart';

void main() {
  testWidgets('bottom toolbar switches between pages', (tester) async {
    await tester.pumpWidget(const TraceApp());

    expect(find.text('Chats'), findsWidgets);
    expect(find.byKey(const Key('calls-page')), findsNothing);

    await tester.tap(find.text('Calls').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calls-page')), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
  });

  testWidgets('conversation opens by tapping and closes back to overview', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-title-maya')), findsOneWidget);
    expect(find.byKey(const Key('neighbor-chat-rail')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-conversation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-row-0')), findsOneWidget);
  });

  testWidgets('swiping a chat row opens that exact conversation', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.drag(
      find.byKey(const Key('conversation-row-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-title-kai')), findsOneWidget);
  });

  testWidgets('the shared avatar rail moves from right to left', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final overviewX = tester
        .getTopLeft(find.byKey(const Key('neighbor-chat-rail')))
        .dx;
    final workspaceX = tester
        .getTopLeft(find.byKey(const Key('chat-workspace')))
        .dx;
    expect(overviewX, greaterThan(250));

    await tester.drag(
      find.byKey(const Key('conversation-row-2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    final focusedX = tester
        .getTopLeft(find.byKey(const Key('neighbor-chat-rail')))
        .dx;
    expect(focusedX, closeTo(workspaceX, 0.1));
    expect(find.byKey(const Key('conversation-title-family')), findsOneWidget);
  });

  testWidgets('the shared seam follows the drag before settling', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final rail = find.byKey(const Key('neighbor-chat-rail'));
    final startX = tester.getTopLeft(rail).dx;
    final selectedAvatar = find.byKey(const Key('rail-book-club'));
    final startAvatarY = tester.getTopLeft(selectedAvatar).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('conversation-row-3'))),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    final draggedX = tester.getTopLeft(rail).dx;
    expect(draggedX, lessThan(startX - 100));
    expect(tester.getTopLeft(selectedAvatar).dy, closeTo(startAvatarY, 0.1));
    expect(
      find.byKey(const Key('conversation-title-book-club')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('swiping a focused chat returns to all chats', (tester) async {
    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('chat-workspace')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-row-0')), findsOneWidget);
  });

  testWidgets('side rail changes the selected chat by tap', (tester) async {
    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rail-kai')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-title-kai')), findsOneWidget);
    expect(find.byKey(const Key('conversation-pager')), findsNothing);
  });

  testWidgets('a short all-chats drag snaps back to the focused chat', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('chat-workspace')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-title-maya')), findsOneWidget);
  });

  testWidgets('message composer adds a local mock message', (tester) async {
    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('message-composer-maya')),
      'Prototype message',
    );
    await tester.tap(find.byKey(const Key('send-message-maya')));
    await tester.pump();

    expect(find.text('Prototype message'), findsOneWidget);
  });
}

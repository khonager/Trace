import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/trace_app.dart';

void main() {
  testWidgets('desktop shows both panes and lets the chat list collapse', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TraceApp());

    expect(find.byKey(const Key('desktop-chat-workspace')), findsOneWidget);
    expect(find.byKey(const Key('conversation-row-0')), findsOneWidget);
    expect(find.byKey(const Key('conversation-title-maya')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('desktop-conversation-pane'))).dx,
      greaterThan(300),
    );

    await tester.tap(find.byKey(const Key('conversation-row-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-title-kai')), findsOneWidget);

    await tester.tap(find.byKey(const Key('desktop-chat-list-toggle')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show chat list'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('desktop-conversation-pane'))).dx,
      closeTo(0, 0.1),
    );

    await tester.tap(find.byKey(const Key('desktop-chat-list-toggle')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide chat list'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('desktop-conversation-pane'))).dx,
      greaterThan(300),
    );
  });

  testWidgets('desktop chat taps use a short background crossfade', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('conversation-row-1')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const Key('conversation-background-canvas-maya')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation-background-canvas-kai')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('conversation-background-canvas-maya')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('conversation-background-canvas-kai')),
      findsOneWidget,
    );
  });

  testWidgets('dragging a chat manually reveals its background', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('conversation-row-1'))),
    );
    await gesture.moveBy(const Offset(-45, 0));
    await tester.pump();

    final revealFinder = find.byKey(const Key('manual-background-reveal-kai'));
    expect(revealFinder, findsOneWidget);
    expect(
      find.byKey(const Key('conversation-background-canvas-maya')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation-background-canvas-kai')),
      findsOneWidget,
    );

    final firstOpacity = tester.widget<Opacity>(revealFinder).opacity;

    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();

    final secondOpacity = tester.widget<Opacity>(revealFinder).opacity;
    expect(secondOpacity, greaterThan(firstOpacity));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-title-kai')), findsOneWidget);
    expect(revealFinder, findsNothing);
  });

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

  testWidgets('some test contacts use profile photos and groups use initials', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-maya')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-kai')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-family')),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  testWidgets('profile photos become chat backgrounds with a plain fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    expect(
      find.byKey(const Key('conversation-background-image-maya')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('conversation-row-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('conversation-background-family')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation-background-image-family')),
      findsNothing,
    );
  });

  testWidgets('conversation opens by tapping and closes back to overview', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-title-maya')), findsOneWidget);
    expect(find.byKey(const Key('neighbor-chat-rail')), findsNothing);

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

  testWidgets('overview cards contain right-aligned profiles and chat text', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final card = tester.getRect(find.byKey(const Key('conversation-row-0')));
    final avatar = tester.getCenter(find.byKey(const Key('rail-maya')));
    final time = tester.getCenter(
      find.byKey(const Key('conversation-time-maya')),
    );
    final name = tester.getCenter(
      find.byKey(const Key('conversation-name-maya')),
    );

    expect(card.contains(avatar), isTrue);
    expect(time.dx, lessThan(name.dx));
    expect(name.dx, lessThan(avatar.dx));
  });

  testWidgets('card avatars become the left-side chat tabs', (tester) async {
    await tester.pumpWidget(const TraceApp());

    final avatar = find.byKey(const Key('rail-kai'));
    final overviewX = tester.getTopLeft(avatar).dx;
    final workspaceX = tester
        .getTopLeft(find.byKey(const Key('chat-workspace')))
        .dx;
    expect(overviewX, greaterThan(250));

    await tester.drag(
      find.byKey(const Key('conversation-row-2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    final focusedX = tester.getTopLeft(avatar).dx;
    expect(focusedX, closeTo(workspaceX + 7, 0.1));
    expect(find.byKey(const Key('conversation-title-family')), findsOneWidget);
  });

  testWidgets('the selected card and foreground avatar follow the drag', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final selectedAvatar = find.byKey(const Key('rail-book-club'));
    final otherAvatar = find.byKey(const Key('rail-family'));
    final selectedRow = find.byKey(const Key('conversation-row-3'));
    final startAvatarX = tester.getTopLeft(selectedAvatar).dx;
    final startRowX = tester.getTopLeft(selectedRow).dx;
    final startAvatarY = tester.getTopLeft(selectedAvatar).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('conversation-row-3'))),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    final draggedAvatarX = tester.getTopLeft(selectedAvatar).dx;
    final otherAvatarX = tester.getTopLeft(otherAvatar).dx;
    final selectedRowX = tester.getTopLeft(selectedRow).dx;
    final otherRowX = tester
        .getTopLeft(find.byKey(const Key('conversation-row-2')))
        .dx;
    expect(draggedAvatarX, lessThan(startAvatarX - 70));
    expect(draggedAvatarX, greaterThan(otherAvatarX + 10));
    expect(find.byKey(const Key('selected-avatar-foreground')), findsOneWidget);
    expect(selectedRowX, greaterThan(otherRowX + 10));
    expect(
      draggedAvatarX - selectedRowX,
      closeTo(startAvatarX - startRowX, 0.1),
    );
    expect(tester.getTopLeft(selectedAvatar).dy, closeTo(startAvatarY, 0.1));
    expect(
      find.byKey(const Key('conversation-title-book-club')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('pulling a chat reveals an app-anchored background', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    final background = find.byKey(
      const Key('conversation-background-canvas-maya'),
    );
    final startX = tester.getTopLeft(background).dx;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('conversation-row-0'))),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    expect(tester.getTopLeft(background).dx, closeTo(startX, 0.1));

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

  testWidgets('a visible card-end tab changes the selected chat', (
    tester,
  ) async {
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

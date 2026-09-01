import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/trace_app.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

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

  testWidgets('People shows only direct chats and can return to All', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('people-chats-context')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-avatar-maya')), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-family')), findsNothing);

    await tester.tap(find.byKey(const Key('all-chats-context')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-avatar-family')), findsOneWidget);
  });

  testWidgets('profile pictures open in a downloadable full-size viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TraceApp());
    await tester.tap(find.byKey(const Key('open-profile-picture-maya')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-picture-preview')), findsOneWidget);
    expect(find.byKey(const Key('download-profile-picture')), findsOneWidget);
    expect(find.text('Maya profile picture'), findsOneWidget);
  });

  testWidgets('group messages show the sender name and avatar', (tester) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('conversation-row-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('message-sender-@mom:example.org')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('message-sender-avatar-@mom:example.org')),
      findsOneWidget,
    );
    expect(find.text('Mom'), findsOneWidget);
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

  testWidgets('mobile chat rail can collapse without a back arrow', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-title-maya')), findsOneWidget);
    expect(find.byKey(const Key('neighbor-chat-rail')), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    final pane = find.byKey(const Key('mobile-conversation-pane'));
    expect(tester.getTopLeft(pane).dx, closeTo(48, 0.1));

    await tester.tap(find.byKey(const Key('mobile-chat-rail-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pane).dx, closeTo(0, 0.1));
    expect(find.byTooltip('Show chat tabs'), findsOneWidget);
  });

  testWidgets('chat header actions use the available width', (tester) async {
    await tester.pumpWidget(const TraceApp());

    final overview = tester.getRect(find.byKey(const Key('chat-overview')));
    final newChat = tester.getRect(find.byKey(const Key('new-chat')));

    expect(overview.right - newChat.right, closeTo(10, 0.1));
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

  testWidgets('swiping a chat row starts loading before the swipe ends', (
    tester,
  ) async {
    final client = _TimelineSpyClient([
      _room(id: 'one', name: 'One'),
      _room(id: 'two', name: 'Two'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ChatsPage(client: client)));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('conversation-row-1'))),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    expect(client.openedRoomIds, contains('two'));

    await gesture.up();
    await tester.pumpAndSettle();
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
    final preview = tester.getRect(
      find.byKey(const Key('conversation-preview-maya')),
    );
    final avatarRect = tester.getRect(find.byKey(const Key('rail-maya')));
    expect(avatarRect.left - preview.right, greaterThanOrEqualTo(10));
  });

  testWidgets('Matrix avatars use the authenticated media thumbnail loader', (
    tester,
  ) async {
    final client = _TimelineSpyClient(
      [
        _room(
          id: 'notes',
          name: 'Notes',
          avatarMediaUri: Uri.parse('mxc://example.org/notes-avatar'),
        ),
      ],
      mediaBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ChatsPage(client: client)));
    await tester.pump();

    expect(
      client.thumbnailRequests,
      contains(Uri.parse('mxc://example.org/notes-avatar')),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-notes')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
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
    expect(focusedX, closeTo(workspaceX - 18, 0.1));
    final focusedAvatar = tester.getRect(avatar);
    expect(focusedAvatar.right, closeTo(workspaceX + 32, 0.1));
    expect(find.byKey(const Key('conversation-title-family')), findsOneWidget);
  });

  testWidgets('settled chat keeps only the header copy of its avatar', (
    tester,
  ) async {
    await tester.pumpWidget(const TraceApp());

    await tester.tap(find.byKey(const Key('conversation-row-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selected-avatar-foreground')), findsNothing);
    expect(find.byKey(const Key('rail-kai')), findsNothing);
    expect(find.byKey(const Key('open-profile-picture-kai')), findsOneWidget);
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

MatrixRoom _room({
  required String id,
  required String name,
  Uri? avatarMediaUri,
}) => MatrixRoom(
  id: id,
  name: name,
  preview: '',
  timestamp: DateTime.utc(2026, 1, 1),
  membership: MatrixRoomMembership.joined,
  unreadCount: 0,
  encrypted: true,
  isDirect: true,
  directUserId: '@$id:example.org',
  avatarMediaUri: avatarMediaUri,
);

final class _TimelineSpyClient implements MatrixClientPort {
  _TimelineSpyClient(List<MatrixRoom> rooms, {this.mediaBytes})
    : current = MatrixClientSnapshot(
        phase: MatrixConnectionPhase.ready,
        rooms: rooms,
      );

  @override
  final MatrixClientSnapshot current;
  final List<int>? mediaBytes;

  final List<String> openedRoomIds = [];
  final List<Uri> thumbnailRequests = [];

  @override
  Stream<MatrixClientSnapshot> get snapshots => const Stream.empty();

  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      const Stream.empty();

  @override
  Future<MatrixTimelinePort> openTimeline(String roomId) async {
    openedRoomIds.add(roomId);
    return _EmptyTimeline();
  }

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<Uint8List> downloadMediaThumbnail(
    Uri mxcUri, {
    int width = 96,
    int height = 96,
  }) async {
    thumbnailRequests.add(mxcUri);
    return Uint8List.fromList(mediaBytes ?? const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmptyTimeline implements MatrixTimelinePort {
  @override
  bool get canLoadOlder => false;

  @override
  List<MatrixMessage> get current => const [];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('sends a custom Matrix reaction from the message menu', (
    tester,
  ) async {
    final timeline = _ReactionTimeline(_message());
    await _pumpChat(tester, timeline);

    await tester.longPress(find.text('Hello from Matrix').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-reaction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-reaction-input')),
      '🫡',
    );
    await tester.tap(find.byKey(const Key('confirm-custom-reaction')));
    await tester.pumpAndSettle();

    expect(timeline.toggles, const [('event-1', '🫡')]);
  });

  testWidgets('shows and toggles off the current Matrix reaction', (
    tester,
  ) async {
    final timeline = _ReactionTimeline(_message(reactionByMe: '🔥'));
    await _pumpChat(tester, timeline);

    expect(find.byKey(const Key('my-reaction-event-1')), findsOneWidget);
    await tester.longPress(find.text('Hello from Matrix').last);
    await tester.pumpAndSettle();
    expect(find.text('Change reaction'), findsOneWidget);
    await tester.tap(find.text('Change reaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reaction-🔥')));
    await tester.pumpAndSettle();

    expect(timeline.toggles, const [('event-1', '🔥')]);
  });
}

Future<void> _pumpChat(WidgetTester tester, _ReactionTimeline timeline) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: ChatsPage(client: _ReactionClient(timeline))),
    ),
  );
  await tester.tap(find.byKey(const Key('conversation-row-0')));
  await tester.pumpAndSettle();
}

MatrixMessage _message({String? reactionByMe}) => MatrixMessage(
  eventId: 'event-1',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'Hello from Matrix',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
  reactionByMe: reactionByMe,
);

final class _ReactionClient implements MatrixClientPort {
  _ReactionClient(this.timeline);

  final _ReactionTimeline timeline;

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Alice',
        preview: 'Hello from Matrix',
        timestamp: DateTime.utc(2026, 8, 31, 12),
        membership: MatrixRoomMembership.joined,
        unreadCount: 0,
        encrypted: true,
        isDirect: true,
        directUserId: '@alice:example.org',
      ),
    ],
  );

  @override
  Stream<MatrixClientSnapshot> get snapshots => const Stream.empty();

  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      const Stream.empty();

  @override
  Future<MatrixTimelinePort> openTimeline(String roomId) async => timeline;

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReactionTimeline implements MatrixTimelinePort {
  _ReactionTimeline(MatrixMessage message) : current = [message];

  @override
  final List<MatrixMessage> current;

  final List<(String, String)> toggles = [];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> toggleReaction(String eventId, String emoji) async {
    toggles.add((eventId, emoji));
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

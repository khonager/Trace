import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('renders reply context and preserves reply target when sending', (
    tester,
  ) async {
    final client = _ReplyClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: ChatsPage(client: client)),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reply-preview-original-event')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Original message'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('reply-preview-original-event')));
    await tester.pumpAndSettle();
    expect(find.text('The original message is not loaded yet.'), findsNothing);

    await tester.longPress(find.text('Original message').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('message-composer-room-1')),
      'A new reply',
    );
    await tester.tap(find.byKey(const Key('send-message-room-1')));
    await tester.pump();

    expect(client.sent, const [('A new reply', 'original-event')]);
  });
}

final class _ReplyClient implements MatrixClientPort {
  final List<(String, String?)> sent = [];

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Alice',
        preview: 'This is a reply',
        timestamp: DateTime.utc(2026, 8, 31),
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
  Future<MatrixTimelinePort> openTimeline(String roomId) async =>
      _ReplyTimeline();

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  Future<void> sendText({
    required String roomId,
    required String body,
    String? replyToEventId,
  }) async {
    sent.add((body, replyToEventId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReplyTimeline implements MatrixTimelinePort {
  @override
  List<MatrixMessage> get current => [_reply, _original];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final MatrixMessage _original = MatrixMessage(
  eventId: 'original-event',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'Original message',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
);

final MatrixMessage _reply = MatrixMessage(
  eventId: 'reply-event',
  senderId: '@me:example.org',
  senderName: 'Me',
  body: 'This is a reply',
  timestamp: DateTime.utc(2026, 8, 31, 12, 1),
  sentByMe: true,
  delivery: MatrixMessageDelivery.synced,
  replyToEventId: 'original-event',
  replyToSenderName: 'Alice',
  replyToBody: 'Original message',
);

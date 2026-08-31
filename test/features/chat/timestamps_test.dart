import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('separates days and only shows inline times for today', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final older = today.subtract(const Duration(days: 2));
    final timeline = _TimestampTimeline([
      _message('older-event', 'An older message', older),
      _message('today-event', 'A message from today', today),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: ChatsPage(client: _TimestampClient(timeline))),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('message-date-${older.year}-${older.month}-${older.day}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('message-date-${today.year}-${today.month}-${today.day}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('message-time-older-event')), findsNothing);
    expect(find.byKey(const Key('message-time-today-event')), findsOneWidget);

    await tester.longPress(
      find.byKey(const Key('message-surface-older-event')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-details-timestamp')), findsOneWidget);
  });
}

MatrixMessage _message(String eventId, String body, DateTime timestamp) =>
    MatrixMessage(
      eventId: eventId,
      senderId: '@alice:example.org',
      senderName: 'Alice',
      body: body,
      timestamp: timestamp,
      sentByMe: false,
      delivery: MatrixMessageDelivery.synced,
    );

final class _TimestampClient implements MatrixClientPort {
  _TimestampClient(this.timeline);

  final MatrixTimelinePort timeline;

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Timestamp test',
        preview: 'A message from today',
        timestamp: DateTime.now(),
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

final class _TimestampTimeline implements MatrixTimelinePort {
  _TimestampTimeline(this.current);

  @override
  final List<MatrixMessage> current;

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

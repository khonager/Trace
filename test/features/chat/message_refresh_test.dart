import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('rebuilds an image when a requested room key decrypts it', (
    tester,
  ) async {
    final timeline = _DecryptingTimeline();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: ChatsPage(client: _RefreshClient(timeline))),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to decrypt this message.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('request-room-key-event-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-image-photo.png')), findsOneWidget);
    expect(find.text('Unable to decrypt this message.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _RefreshClient implements MatrixClientPort {
  _RefreshClient(this.timeline);

  final _DecryptingTimeline timeline;

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Encrypted room',
        preview: '',
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
  Future<MatrixTimelinePort> openTimeline(String roomId) async => timeline;

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DecryptingTimeline implements MatrixTimelinePort {
  final StreamController<List<MatrixMessage>> _updates =
      StreamController.broadcast();
  List<MatrixMessage> _current = [_encryptedMessage];

  @override
  List<MatrixMessage> get current => _current;

  @override
  Stream<List<MatrixMessage>> get updates => _updates.stream;

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> requestKey(String eventId) async {
    _current = [_imageMessage];
    _updates.add(_current);
  }

  @override
  Future<MatrixAttachmentData> downloadAttachment(
    String eventId, {
    bool thumbnail = false,
  }) async => MatrixAttachmentData(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
    name: 'photo.png',
    mimeType: 'image/png',
  );

  @override
  Future<void> close() => _updates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final MatrixMessage _encryptedMessage = MatrixMessage(
  eventId: 'event-1',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'Unable to decrypt this message.',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
  isUndecryptable: true,
  canRequestKey: true,
);

final MatrixMessage _imageMessage = MatrixMessage(
  eventId: 'event-1',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'photo.png',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
  kind: MatrixMessageKind.image,
  attachmentName: 'photo.png',
  attachmentMimeType: 'image/png',
);

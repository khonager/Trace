import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('opens and downloads the original received image', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final timeline = _ImageTimeline();
    MatrixAttachmentData? savedAttachment;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(
          body: ChatsPage(
            client: _ImageClient(timeline),
            saveAttachment: (attachment) async {
              savedAttachment = attachment;
              return '/tmp/${attachment.name}';
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    final mediaSurface = tester.widget<Container>(
      find.byKey(const Key('message-surface-image-event')),
    );
    expect(mediaSurface.decoration, isNull);
    expect(mediaSurface.padding, EdgeInsets.zero);

    final openImage = find
        .ancestor(
          of: find.byKey(const Key('message-image-photo.png')),
          matching: find.byType(InkWell),
        )
        .first;
    final previewSize = tester.getSize(
      find.byKey(const Key('message-image-frame-photo.png')),
    );
    expect(previewSize.height, greaterThan(180));
    expect(previewSize.height, lessThanOrEqualTo(300));
    tester.widget<InkWell>(openImage).onTap!();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('received-image-preview')), findsOneWidget);
    expect(timeline.thumbnailRequests, [true, false]);

    await tester.tap(find.byKey(const Key('download-received-image')));
    await tester.pumpAndSettle();

    expect(savedAttachment?.name, 'photo.png');
    expect(savedAttachment?.mimeType, 'image/png');
    expect(timeline.thumbnailRequests, [true, false]);
  });

  testWidgets('pending images fall back to locally cached original bytes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final timeline = _PendingImageTimeline();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: ChatsPage(client: _ImageClient(timeline))),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-image-sending.gif')), findsOneWidget);
    expect(find.text('Load image again'), findsNothing);
    expect(timeline.thumbnailRequests, [true, false]);
  });
}

final class _ImageClient implements MatrixClientPort {
  _ImageClient(this.timeline);

  final MatrixTimelinePort timeline;

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Photos',
        preview: 'photo.png',
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

final class _PendingImageTimeline implements MatrixTimelinePort {
  final List<bool> thumbnailRequests = [];

  @override
  List<MatrixMessage> get current => [_pendingImageMessage];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<MatrixAttachmentData> downloadAttachment(
    String eventId, {
    bool thumbnail = false,
  }) async {
    thumbnailRequests.add(thumbnail);
    if (thumbnail) throw StateError('Thumbnail is still being generated.');
    return MatrixAttachmentData(
      bytes: base64Decode('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=='),
      name: 'sending.gif',
      mimeType: 'image/gif',
    );
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ImageTimeline implements MatrixTimelinePort {
  final List<bool> thumbnailRequests = [];

  @override
  List<MatrixMessage> get current => [_imageMessage];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<MatrixAttachmentData> downloadAttachment(
    String eventId, {
    bool thumbnail = false,
  }) async {
    thumbnailRequests.add(thumbnail);
    return MatrixAttachmentData(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      name: 'photo.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final MatrixMessage _imageMessage = MatrixMessage(
  eventId: 'image-event',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'photo.png',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
  kind: MatrixMessageKind.image,
  attachmentName: 'photo.png',
  attachmentMimeType: 'image/png',
  attachmentWidth: 1,
  attachmentHeight: 1,
);

final MatrixMessage _pendingImageMessage = MatrixMessage(
  eventId: 'pending-image-event',
  senderId: '@me:example.org',
  senderName: 'Me',
  body: 'sending.gif',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: true,
  delivery: MatrixMessageDelivery.sending,
  kind: MatrixMessageKind.image,
  attachmentName: 'sending.gif',
  attachmentMimeType: 'image/gif',
  attachmentWidth: 1,
  attachmentHeight: 1,
);

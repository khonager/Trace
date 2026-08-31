import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('opens an HTTP link without trailing sentence punctuation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(
          body: ChatsPage(
            client: _LinkClient(),
            openLink: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('conversation-row-0')));
    await tester.pumpAndSettle();

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const Key('message-text-link-event')),
        matching: find.byType(RichText),
      ),
    );
    final linkSpan = _findLinkSpan(richText.text)!;
    (linkSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();

    expect(openedUri, Uri.parse('https://example.org/docs'));
  });
}

TextSpan? _findLinkSpan(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.recognizer is TapGestureRecognizer) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final match = _findLinkSpan(child);
    if (match != null) return match;
  }
  return null;
}

final class _LinkClient implements MatrixClientPort {
  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Links',
        preview: 'https://example.org/docs.',
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
      _LinkTimeline();

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LinkTimeline implements MatrixTimelinePort {
  @override
  List<MatrixMessage> get current => [_linkMessage];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final MatrixMessage _linkMessage = MatrixMessage(
  eventId: 'link-event',
  senderId: '@alice:example.org',
  senderName: 'Alice',
  body: 'https://example.org/docs.',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  sentByMe: false,
  delivery: MatrixMessageDelivery.synced,
);

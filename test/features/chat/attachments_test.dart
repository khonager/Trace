import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/attachment_picker.dart';
import 'package:trace/features/chat/application/composer_actions.dart';
import 'package:trace/features/chat/application/media_search.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';

void main() {
  testWidgets('shows an actionable error when the system picker fails', (
    tester,
  ) async {
    await _openChat(
      tester,
      client: _AttachmentClient(),
      picker: () async => throw Exception('FileChooser is unavailable'),
    );

    await _chooseComposerAction(tester, 'Attach file');
    await tester.pumpAndSettle();

    expect(
      find.text('File picker could not open: FileChooser is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('reads and sends the selected attachment', (tester) async {
    final client = _AttachmentClient();
    await _openChat(
      tester,
      client: client,
      picker: () async => ChatAttachment(
        name: 'notes.txt',
        readAsBytes: () async => Uint8List.fromList('hello'.codeUnits),
      ),
    );

    await _chooseComposerAction(tester, 'Attach file');
    await tester.pumpAndSettle();

    expect(client.sentName, 'notes.txt');
    expect(client.sentMimeType, 'text/plain');
    expect(client.sentBytes, Uint8List.fromList('hello'.codeUnits));
    expect(find.text('notes.txt sent.'), findsOneWidget);
  });

  testWidgets('long pressing an action pins it above the input field', (
    tester,
  ) async {
    final pinStore = _MemoryPinStore();
    await _openChat(
      tester,
      client: _AttachmentClient(),
      picker: () async => null,
      pinStore: pinStore,
    );

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Search GIFs'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pinned-composer-actions')), findsOneWidget);
    expect(
      find.byKey(const Key('pinned-composer-action-gifSearch')),
      findsOneWidget,
    );
    expect(pinStore.actions, [ComposerAction.gifSearch]);
  });

  testWidgets('searches for and sends a GIF through the media port', (
    tester,
  ) async {
    final client = _AttachmentClient();
    final mediaSearch = _FakeMediaSearch();
    await _openChat(
      tester,
      client: client,
      picker: () async => null,
      mediaSearch: mediaSearch,
    );

    await _chooseComposerAction(tester, 'Search GIFs');
    expect(find.text('Open web search'), findsNothing);
    await tester.enterText(find.byKey(const Key('media-search-gif')), 'waves');
    await tester.tap(find.byKey(const Key('media-search-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-search-result-wave')));
    await tester.pumpAndSettle();

    expect(mediaSearch.query, 'waves');
    expect(mediaSearch.safety, MediaSearchSafety.open);
    expect(client.sentName, 'A-wave.gif');
    expect(client.sentMimeType, 'image/gif');
    expect(client.sentBytes, Uint8List.fromList([71, 73, 70]));
  });

  testWidgets('sends rich GIF content inserted by an Android keyboard', (
    tester,
  ) async {
    final client = _AttachmentClient();
    await _openChat(tester, client: client, picker: () async => null);
    final composer = tester.widget<TextField>(
      find.byKey(const Key('message-composer-room-1')),
    );

    composer.contentInsertionConfiguration!.onContentInserted(
      KeyboardInsertedContent(
        mimeType: 'image/gif',
        uri: 'content://keyboard/selected-gif',
        data: Uint8List.fromList([71, 73, 70]),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.sentName, endsWith('.gif'));
    expect(client.sentMimeType, 'image/gif');
    expect(client.sentBytes, Uint8List.fromList([71, 73, 70]));
    expect(find.text('Keyboard media sent.'), findsOneWidget);
  });
}

Future<void> _chooseComposerAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Add'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _openChat(
  WidgetTester tester, {
  required _AttachmentClient client,
  required Future<ChatAttachment?> Function() picker,
  ComposerActionPinStore? pinStore,
  MediaSearchPort? mediaSearch,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
        body: ChatsPage(
          client: client,
          pickAttachment: picker,
          composerActionPinStore: pinStore,
          mediaSearch: mediaSearch,
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('conversation-row-0')));
  await tester.pumpAndSettle();
}

final class _MemoryPinStore implements ComposerActionPinStore {
  List<ComposerAction> actions = const [];

  @override
  Future<List<ComposerAction>> load() async => actions;

  @override
  Future<void> save(List<ComposerAction> actions) async {
    this.actions = List.unmodifiable(actions);
  }
}

final class _FakeMediaSearch implements MediaSearchPort {
  String? query;
  MediaSearchSafety? safety;

  @override
  bool get isConfigured => true;

  @override
  Future<List<MediaSearchResult>> search({
    required String query,
    required MediaSearchKind kind,
    required MediaSearchSafety safety,
  }) async {
    this.query = query;
    this.safety = safety;
    return [
      MediaSearchResult(
        id: 'wave',
        title: 'A wave',
        previewUri: Uri.parse('https://relay.example/preview/wave'),
        downloadUri: Uri.parse('https://relay.example/download/wave'),
        mimeType: 'image/gif',
        source: 'Brave',
      ),
    ];
  }

  @override
  Future<DownloadedMedia> download(MediaSearchResult result) async =>
      DownloadedMedia(
        bytes: Uint8List.fromList([71, 73, 70]),
        mimeType: 'image/gif',
      );
}

final class _AttachmentClient implements MatrixClientPort {
  String? sentName;
  String? sentMimeType;
  Uint8List? sentBytes;

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      MatrixRoom(
        id: 'room-1',
        name: 'Files',
        preview: 'Share a file',
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
      _EmptyTimeline();

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  Future<void> sendFile({
    required String roomId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    sentName = name;
    sentMimeType = mimeType;
    sentBytes = bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmptyTimeline implements MatrixTimelinePort {
  @override
  List<MatrixMessage> get current => const [];

  @override
  Stream<List<MatrixMessage>> get updates => const Stream.empty();

  @override
  bool get canLoadOlder => false;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

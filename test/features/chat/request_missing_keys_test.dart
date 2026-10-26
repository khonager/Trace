import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/request_missing_keys.dart';

void main() {
  test(
    'scans unopened chats and older history, continuing after a room fails',
    () async {
      final client = _Client();
      final progress = <String>[];
      final result = await requestAllMissingKeys(
        client,
        cancelled: () => false,
        onProgress: (name, _, _) => progress.add(name),
      );
      expect(progress, ['one', 'broken', 'two']);
      expect(client.timelines['one']!.pages, 2);
      expect(client.timelines['two']!.pages, 2);
      expect(result.requested, 4);
      expect(result.failedRooms, 1);
      expect(result.cancelled, isFalse);
    },
  );
  test('cancelling stops before opening another room', () async {
    final client = _Client();
    var cancel = false;
    final result = await requestAllMissingKeys(
      client,
      cancelled: () => cancel,
      onProgress: (_, _, _) => cancel = true,
    );
    expect(result.cancelled, isTrue);
    expect(result.requested, 0);
    expect(client.timelines['two']!.pages, 0);
  });
}

class _Client implements MatrixClientPort {
  final timelines = {'one': _Timeline(), 'two': _Timeline()};
  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      for (final id in ['one', 'broken', 'two', 'plain'])
        MatrixRoom(
          id: id,
          name: id,
          preview: '',
          timestamp: DateTime(2026),
          membership: MatrixRoomMembership.joined,
          unreadCount: 0,
          encrypted: id != 'plain',
          isDirect: true,
        ),
    ],
  );
  @override
  Future<MatrixTimelinePort> openTimeline(String roomId) async {
    if (roomId == 'broken') throw StateError('offline');
    return timelines[roomId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Timeline implements MatrixTimelinePort {
  int pages = 0;
  @override
  bool get canLoadOlder => pages < 2;
  @override
  Future<void> loadOlder() async {
    pages++;
  }

  @override
  Future<int> requestMissingKeys({String? eventId}) async => 2;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

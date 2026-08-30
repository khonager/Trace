import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

void main() {
  test('spaces are containers and include rooms from nested spaces', () {
    final now = DateTime(2026);
    MatrixRoom room(
      String id, {
      bool space = false,
      List<String> children = const [],
      bool direct = false,
      String? directUserId,
      bool pinned = false,
      double? pinOrder,
      int minute = 0,
    }) => MatrixRoom(
      id: id,
      name: id,
      preview: '',
      timestamp: now.add(Duration(minutes: minute)),
      membership: MatrixRoomMembership.joined,
      unreadCount: 0,
      encrypted: true,
      isDirect: direct,
      directUserId: directUserId,
      isSpace: space,
      childRoomIds: children,
      isPinned: pinned,
      pinOrder: pinOrder,
    );

    final rooms = [
      room('root', space: true, children: const ['nested', 'alpha']),
      room('nested', space: true, children: const ['beta']),
      room('alpha'),
      room('beta'),
      room('outside'),
    ];

    expect(matrixChatRoomsForSpace(rooms).map((room) => room.id), [
      'alpha',
      'beta',
      'outside',
    ]);
    expect(
      matrixChatRoomsForSpace(rooms, spaceId: 'root').map((room) => room.id),
      ['beta', 'alpha'],
    );
  });

  test('direct chats contain people but no groups or Saved Messages', () {
    final now = DateTime(2026);
    MatrixRoom room(String id, {bool direct = false, String? directUserId}) =>
        MatrixRoom(
          id: id,
          name: id,
          preview: '',
          timestamp: now,
          membership: MatrixRoomMembership.joined,
          unreadCount: 0,
          encrypted: true,
          isDirect: direct,
          directUserId: directUserId,
        );

    final rooms = [
      room('person', direct: true, directUserId: '@alice:example.org'),
      room('saved-messages'),
      room('group'),
      room('malformed-direct', direct: true),
    ];

    expect(matrixDirectChatRooms(rooms).map((room) => room.id), ['person']);
  });

  test('all chats put every ordered pinned chat before recent rooms', () {
    final now = DateTime(2026);
    MatrixRoom room(
      String id, {
      required DateTime timestamp,
      bool direct = false,
      bool pinned = false,
      double? pinOrder,
    }) => MatrixRoom(
      id: id,
      name: id,
      preview: '',
      timestamp: timestamp,
      membership: MatrixRoomMembership.joined,
      unreadCount: 0,
      encrypted: true,
      isDirect: direct,
      isPinned: pinned,
      pinOrder: pinOrder,
    );

    final rooms = [
      room('recent', timestamp: now.add(const Duration(hours: 3))),
      room('pin-2', timestamp: now, direct: true, pinned: true, pinOrder: .8),
      room('saved-messages', timestamp: now, pinned: true, pinOrder: .2),
      room('older', timestamp: now),
    ];

    expect(matrixChatRoomsForSpace(rooms).map((room) => room.id), [
      'saved-messages',
      'pin-2',
      'recent',
      'older',
    ]);
  });
}

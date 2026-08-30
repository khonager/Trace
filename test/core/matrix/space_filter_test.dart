import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

void main() {
  test('spaces are containers and include rooms from nested spaces', () {
    final now = DateTime(2026);
    MatrixRoom room(
      String id, {
      bool space = false,
      List<String> children = const [],
    }) => MatrixRoom(
      id: id,
      name: id,
      preview: '',
      timestamp: now,
      membership: MatrixRoomMembership.joined,
      unreadCount: 0,
      encrypted: true,
      isDirect: false,
      isSpace: space,
      childRoomIds: children,
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
      ['alpha', 'beta'],
    );
  });
}

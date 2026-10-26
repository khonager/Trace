import 'package:trace/core/matrix/matrix_client_port.dart';

class MissingKeyRequestResult {
  const MissingKeyRequestResult(
    this.requested,
    this.failedRooms,
    this.cancelled,
  );
  final int requested;
  final int failedRooms;
  final bool cancelled;
}

/// Explicit recovery sweep, including older accessible history and unopened
/// rooms. Requests are deduplicated by session within each room by the adapter.
Future<MissingKeyRequestResult> requestAllMissingKeys(
  MatrixClientPort client, {
  required bool Function() cancelled,
  required void Function(String roomName, int completed, int total) onProgress,
}) async {
  final rooms = client.current.rooms
      .where(
        (room) =>
            room.encrypted &&
            !room.isSpace &&
            room.membership == MatrixRoomMembership.joined,
      )
      .toList();
  var requested = 0;
  var failed = 0;
  for (var index = 0; index < rooms.length; index++) {
    if (cancelled()) break;
    final room = rooms[index];
    onProgress(room.name, index, rooms.length);
    try {
      final timeline = await client.openTimeline(room.id);
      while (timeline.canLoadOlder && !cancelled()) {
        await timeline.loadOlder();
      }
      if (cancelled()) break;
      requested += await timeline.requestMissingKeys();
    } catch (_) {
      failed++;
    }
  }
  return MissingKeyRequestResult(requested, failed, cancelled());
}

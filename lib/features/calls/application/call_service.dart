import 'package:flutter/foundation.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

enum CallPhase { preparing, ringing, connecting, connected, ending }

@immutable
class TraceCall {
  const TraceCall({
    required this.roomId,
    required this.phase,
    required this.incoming,
    this.muted = false,
  });
  final String roomId;
  final CallPhase phase;
  final bool incoming;
  final bool muted;
  bool get canAnswer => incoming && phase == CallPhase.ringing;
}

/// Optional capability; clients without a WebRTC implementation remain usable.
abstract interface class CallingClientPort {
  CallService get calls;
}

abstract class CallService extends ChangeNotifier {
  TraceCall? get current;
  String? get error;
  bool get busy;
  void setAvailability({
    required bool foreground,
    required bool Function(String) roomAllowed,
  });
  Future<void> start(MatrixRoom room);
  Future<void> answer();
  Future<void> end();
  Future<void> toggleMute();
  void clearError();
}

bool canCallRoom(MatrixRoom room) =>
    room.membership == MatrixRoomMembership.joined &&
    room.isDirect &&
    !room.isSpace &&
    room.directUserId != null;

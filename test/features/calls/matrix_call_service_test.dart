import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:trace/infrastructure/matrix/matrix_call_service.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

class _Database implements matrix.DatabaseApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Media extends MediaDevices {
  int opens = 0;
  @override
  Future<MediaStream> getUserMedia(Map<String, dynamic> constraints) async {
    opens++;
    return _Stream();
  }

  @override
  Future<MediaStream> getDisplayMedia(Map<String, dynamic> constraints) async =>
      throw StateError('No screen capture');
  @override
  Future<List<MediaDeviceInfo>> enumerateDevices() async => [];
  @override
  Future<List<dynamic>> getSources() async => [];
}

class _Stream implements MediaStream {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('incoming Matrix preparation never opens the microphone', () async {
    final client = matrix.Client('call-test', database: _Database());
    final room = matrix.Room(
      id: '!room:example.org',
      client: client,
      summary: matrix.RoomSummary.fromJson({'m.joined_member_count': 2}),
    );
    client.rooms.add(room);
    final devices = _Media();
    final empty = _Stream();
    var emptyStreams = 0;
    final service = MatrixCallService(
      client,
      platformMediaDevices: devices,
      createEmptyStream: (_) async {
        emptyStreams++;
        return empty;
      },
    );
    service.setAvailability(foreground: true, roomAllowed: (_) => true);
    final session = matrix.CallSession(
      CallOptions(
        callId: 'incoming',
        type: matrix.CallType.kVoice,
        dir: matrix.CallDirection.kIncoming,
        localPartyId: 'device',
        voip: matrix.VoIP(client, service),
        room: room,
        iceServers: [],
      ),
    );
    await service.registerListeners(session);
    expect(
      await service.mediaDevices.getUserMedia({'audio': true}),
      same(empty),
    );
    expect(devices.opens, 0);
    expect(emptyStreams, 1);
    await service.handleCallEnded(session);
    await service.close();
    await expectLater(
      service.mediaDevices.getUserMedia({'audio': true}),
      throwsStateError,
    );
    expect(devices.opens, 0);
  });
}

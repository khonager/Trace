import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/calls/application/call_service.dart';
import 'package:trace/features/calls/presentation/calls_page.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';

class FakeCalls extends CallService {
  @override
  TraceCall? current;
  @override
  String? error;
  @override
  bool busy = false;
  int answers = 0;
  int endings = 0;
  int mutes = 0;
  String? startedRoom;
  @override
  Future<void> start(MatrixRoom room) async {
    startedRoom = room.id;
  }

  @override
  Future<void> answer() async {
    answers++;
  }

  @override
  Future<void> end() async {
    endings++;
  }

  @override
  Future<void> toggleMute() async {
    mutes++;
  }

  @override
  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void setAvailability({
    required bool foreground,
    required bool Function(String) roomAllowed,
  }) {}
}

class FakeCallClient implements MatrixClientPort {
  FakeCallClient(this.rooms);
  final List<MatrixRoom> rooms;
  @override
  MatrixClientSnapshot get current =>
      MatrixClientSnapshot(phase: MatrixConnectionPhase.ready, rooms: rooms);
  @override
  Stream<MatrixClientSnapshot> get snapshots => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MatrixRoom callRoom(String id, {bool direct = true}) => MatrixRoom(
  id: id,
  name: id,
  preview: '',
  timestamp: DateTime(2026),
  membership: MatrixRoomMembership.joined,
  unreadCount: 0,
  encrypted: true,
  isDirect: direct,
  directUserId: direct ? '@friend:example.org' : null,
);
void main() {
  testWidgets(
    'incoming controls answer and decline the real service capability',
    (tester) async {
      final calls = FakeCalls()
        ..current = const TraceCall(
          roomId: 'Friend',
          phase: CallPhase.ringing,
          incoming: true,
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControls(
              calls: calls,
              client: FakeCallClient([callRoom('Friend')]),
            ),
          ),
        ),
      );
      expect(find.text('Incoming voice call'), findsOneWidget);
      await tester.tap(find.text('Answer'));
      await tester.tap(find.text('Decline'));
      expect(calls.answers, 1);
      expect(calls.endings, 1);
      calls.current = const TraceCall(
        roomId: 'Friend',
        phase: CallPhase.connected,
        incoming: true,
      );
      calls.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Mute'));
      expect(calls.mutes, 1);
      expect(find.text('Answer'), findsNothing);
    },
  );
  testWidgets(
    'only available direct chats can be dialed; locked chats stay private',
    (tester) async {
      final calls = FakeCalls();
      final locks = LockController(
        read: () async => '{"Locked":{"method":"device"}}',
        authenticateDevice: (_) async => true,
      );
      addTearDown(locks.dispose);
      await locks.load();
      final client = FakeCallClient([
        callRoom('Friend'),
        callRoom('Group', direct: false),
        callRoom('Locked'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: LockScope(
            controller: locks,
            child: Scaffold(
              body: CallsPage(calls: calls, client: client),
            ),
          ),
        ),
      );
      expect(find.text('Group'), findsNothing);
      expect(find.text('Locked'), findsNothing);
      await tester.tap(find.byTooltip('Call Friend'));
      expect(calls.startedRoom, 'Friend');
      calls.current = const TraceCall(
        roomId: 'Locked',
        phase: CallPhase.ringing,
        incoming: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LockScope(
            controller: locks,
            child: Scaffold(
              body: CallControls(calls: calls, client: client),
            ),
          ),
        ),
      );
      expect(find.text('Locked'), findsNothing);
      expect(find.text('Answer'), findsNothing);
    },
  );
}

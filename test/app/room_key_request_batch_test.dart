import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'share all only shares the same-device requests pending at the tap',
    () async {
      final client = _Client();
      final controller = MatrixSessionController(client);
      await controller.initialize();
      addTearDown(() async {
        controller.dispose();
        await client.requests.close();
      });

      final first = _Request('PHONE');
      final otherDevice = _Request('TABLET');
      final second = _Request('PHONE');
      final later = _Request('PHONE');
      client.requests.add(first);
      client.requests.add(otherDevice);
      client.requests.add(second);
      await Future<void>.delayed(Duration.zero);
      expect(controller.pendingRoomKeyRequestsForActiveDevice, 2);

      first.onShare = () => client.requests.add(later);
      await controller.sharePendingRoomKeysForActiveDevice();
      await Future<void>.delayed(Duration.zero);

      expect(first.shared, isTrue);
      expect(second.shared, isTrue);
      expect(otherDevice.shared, isFalse);
      expect(later.shared, isFalse);
      expect(controller.activeRoomKeyRequest, same(otherDevice));

      await controller.rejectActiveRoomKey();
      expect(controller.activeRoomKeyRequest, same(later));
      expect(controller.pendingRoomKeyRequestsForActiveDevice, 1);
    },
  );
}

class _Client implements MatrixClientPort {
  final requests = StreamController<MatrixRoomKeyRequestPort>.broadcast();

  @override
  Stream<MatrixRoomKeyRequestPort> get roomKeyRequests => requests.stream;

  @override
  Stream<MatrixClientSnapshot> get snapshots => const Stream.empty();

  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      const Stream.empty();

  @override
  MatrixClientSnapshot get current => const MatrixClientSnapshot.starting();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements MatrixRoomKeyRequestPort {
  _Request(this.deviceId);

  @override
  final String deviceId;
  bool shared = false;
  void Function()? onShare;

  @override
  String get userId => '@alice:example.org';

  @override
  String get deviceName => deviceId;

  @override
  String get roomName => 'Room';

  @override
  Future<void> share() async {
    shared = true;
    onShare?.call();
  }

  @override
  Future<void> reject() async {}
}

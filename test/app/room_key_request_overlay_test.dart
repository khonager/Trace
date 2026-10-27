import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/settings/presentation/matrix_verification_overlay.dart';

void main() {
  testWidgets('an own-device room key request can be approved in Trace', (
    tester,
  ) async {
    final request = _KeyRequest();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: MatrixRoomKeyRequestDialog(
          request: request,
          pendingCount: 2,
          onShare: request.share,
          onShareAll: request.share,
          onReject: request.reject,
        ),
      ),
    );

    expect(
      find.byKey(const Key('matrix-room-key-request-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('Phone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-room-key-request')));
    await tester.pump();

    expect(request.shared, isTrue);
    expect(request.rejected, isFalse);
  });

  testWidgets('share all invokes the one-time pending request action', (
    tester,
  ) async {
    final request = _KeyRequest();
    var sharedAll = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MatrixRoomKeyRequestDialog(
          request: request,
          pendingCount: 3,
          onShare: request.share,
          onShareAll: () async => sharedAll = true,
          onReject: request.reject,
        ),
      ),
    );

    expect(find.textContaining('3 key requests are pending'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-all-room-key-requests')));
    await tester.pump();
    expect(sharedAll, isTrue);
    expect(request.shared, isFalse);
  });
}

final class _KeyRequest implements MatrixRoomKeyRequestPort {
  bool shared = false;
  bool rejected = false;

  @override
  String get userId => '@alice:example.org';

  @override
  String get deviceId => 'PHONE1';

  @override
  String get deviceName => 'Alice’s Phone';

  @override
  String get roomName => 'Encrypted room';

  @override
  Future<void> share() async => shared = true;

  @override
  Future<void> reject() async => rejected = true;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/installation_trust.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/auth/presentation/restored_session_gate.dart';

void main() {
  testWidgets(
    'restored content stays unmounted until authentication succeeds',
    (tester) async {
      const channel = MethodChannel('com.llfbandit.app_links/events');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final trust = _Trust();
      final controller = MatrixSessionController(
        _Client(),
        installationTrust: trust,
      );
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RestoredSessionGate(
            controller: controller,
            child: const Text('Private chats'),
          ),
        ),
      );
      expect(find.text('Private chats'), findsNothing);
      expect(find.text('Is this your account?'), findsOneWidget);
      await tester.tap(find.text('Yes, unlock my chats'));
      await tester.pumpAndSettle();
      expect(find.text('Private chats'), findsNothing);
      expect(trust.remembered, isFalse);
      trust.accept = true;
      await tester.tap(find.text('Yes, unlock my chats'));
      await tester.pumpAndSettle();
      expect(find.text('Private chats'), findsOneWidget);
      expect(trust.remembered, isTrue);
    },
  );
}

class _Trust extends InstallationTrust {
  bool accept = false;
  bool remembered = false;
  @override
  Future<bool> isConfirmed(String userId) async => false;
  @override
  Future<bool> authenticate() async => accept;
  @override
  Future<void> remember(String userId) async {
    remembered = true;
  }
}

class _Client implements MatrixClientPort {
  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    account: MatrixAccount(
      userId: '@alice:example.org',
      displayName: 'Alice',
      homeserver: Uri.parse('https://example.org'),
    ),
  );
  @override
  Stream<MatrixClientSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      const Stream.empty();
  @override
  Stream<MatrixRoomKeyRequestPort> get roomKeyRequests => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/lock_controller.dart';

void main() {
  test(
    'group credentials reveal only their own chats and survive reload',
    () async {
      String? saved;
      final locks = LockController(
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
      );
      await locks.load();
      await locks.configure('group:Work', LockMethod.pattern, secret: '1');
      await locks.verify('group:Work', secret: '1');
      await locks.assignRoom('work-room', 'group:Work');
      await locks.configure('group:Private', LockMethod.passcode, secret: '2');
      await locks.verify('group:Private', secret: '2');
      await locks.assignRoom('private-room', 'group:Private');
      locks.hideGroup('group:Private');
      expect(locks.hidden('work-room'), isFalse);
      expect(locks.hidden('private-room'), isTrue);
      locks.hideGroups();
      expect(locks.hidden('work-room'), isTrue);
      expect(locks.hidden('private-room'), isTrue);
      expect(await locks.verify('group:Work', secret: '2'), isFalse);
      expect(await locks.verify('group:Work', secret: '1'), isTrue);
      expect(locks.hidden('work-room'), isFalse);
      expect(locks.hidden('private-room'), isTrue);
      await expectLater(
        locks.assignRoom('private-room', null),
        throwsStateError,
      );
      final restored = LockController(read: () async => saved);
      await restored.load();
      expect(restored.hidden('work-room'), isTrue);
      expect(restored.hidden('private-room'), isTrue);
    },
    // This exercises six real 600,000-iteration credential derivations.
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('defaults off; corrupt/unavailable storage fails closed', () async {
    final empty = LockController(read: () async => null);
    await empty.load();
    expect(empty.ready, isTrue);
    expect(empty.hasLocks, isFalse);
    final broken = LockController(read: () async => '{bad');
    await broken.load();
    expect(broken.ready, isFalse);
    expect(broken.error, isNotNull);
  });

  test(
    'custom locks persist verifiers and require correct independent secrets',
    () async {
      String? stored;
      final locks = LockController(
        read: () async => stored,
        write: (value) async => stored = value,
      );
      await locks.load();
      await locks.configure('room', LockMethod.passcode, secret: '123456');
      expect(stored, isNot(contains('123456')));
      expect(locks.locked('room'), isTrue);
      expect(await locks.verify('room', secret: '654321'), isFalse);
      expect(await locks.verify('room', secret: '123456'), isTrue);
      expect(locks.locked('room'), isFalse);
      locks.lockAll();
      expect(locks.resumeLock, 'room');
      expect(locks.locked('room'), isTrue);
      await expectLater(locks.configure('room', null), throwsStateError);
      final restarted = LockController(read: () async => stored);
      await restarted.load();
      expect(restarted.locked('room'), isTrue);
      expect(restarted.enabled(LockController.app), isFalse);
    },
  );

  test('failed storage writes do not disable locks', () async {
    final locks = LockController(
      read: () async => jsonEncode({
        'app': {'method': 'device'},
      }),
      write: (_) async => throw StateError('storage'),
      authenticateDevice: (_) async => true,
    );
    await locks.load();
    expect(await locks.verify('app'), isTrue);
    await expectLater(locks.configure('app', null), throwsStateError);
    expect(locks.enabled('app'), isTrue);
  });

  test(
    'stale system authentication cannot unlock after backgrounding',
    () async {
      final result = Completer<bool>();
      final locks = LockController(
        read: () async => '{"app":{"method":"biometric"}}',
        authenticateDevice: (biometric) {
          expect(biometric, isTrue);
          return result.future;
        },
      );
      await locks.load();
      final verification = locks.verify('app');
      locks.lockAll();
      result.complete(true);
      expect(await verification, isFalse);
      expect(locks.locked('app'), isTrue);
    },
  );

  test('five failures throttle further attempts', () async {
    var calls = 0;
    final locks = LockController(
      read: () async => '{"app":{"method":"device"}}',
      authenticateDevice: (_) async {
        calls++;
        return false;
      },
    );
    await locks.load();
    for (var i = 0; i < 6; i++) {
      expect(await locks.verify('app'), isFalse);
    }
    expect(calls, 5);
  });

  test('validates all custom credential formats', () {
    expect(LockController.validate(LockMethod.passcode, '1'), isNull);
    expect(LockController.validate(LockMethod.passcode, '123456'), isNull);
    expect(LockController.validate(LockMethod.password, 'x'), isNull);
    expect(LockController.validate(LockMethod.passcode, ''), isNotNull);
    expect(LockController.validate(LockMethod.passcode, 'a'), isNotNull);
    expect(LockController.validate(LockMethod.password, ''), isNotNull);
    expect(LockController.validate(LockMethod.pattern, '1'), isNull);
    expect(LockController.validate(LockMethod.pattern, '1123'), isNotNull);
    expect(LockController.validate(LockMethod.pattern, '1236'), isNull);
  });
}

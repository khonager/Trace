import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/calls/application/microphone_access.dart';

void main() {
  test('unavailable calls never request microphone permission', () async {
    await expectLater(
      openCallMicrophone<Object>(
        allowed: () => false,
        open: () async => fail('Must not open the microphone'),
        release: (_) async {},
      ),
      throwsStateError,
    );
  });
  test(
    'canceling during a permission prompt releases the late stream',
    () async {
      var allowed = true;
      final permission = Completer<Object>();
      final stream = Object();
      Object? released;
      final request = openCallMicrophone(
        allowed: () => allowed,
        open: () => permission.future,
        release: (value) async => released = value,
      );
      allowed = false;
      final result = expectLater(request, throwsStateError);
      permission.complete(stream);
      await result;
      expect(released, same(stream));
    },
  );
  test('an authorized foreground call receives its stream', () async {
    final stream = Object();
    expect(
      await openCallMicrophone(
        allowed: () => true,
        open: () async => stream,
        release: (_) async => fail('Must retain the live stream'),
      ),
      same(stream),
    );
  });
}

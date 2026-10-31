import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/application/voice_recording.dart';
import 'package:trace/features/chat/presentation/voice_message_dialog.dart';

class FakeRecorder implements VoiceRecorder {
  bool disposed = false;
  bool started = false;
  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<Uint8List> stop() async => Uint8List.fromList([1, 2]);
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  testWidgets('failed send retains recording for an explicit retry', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceMessageDialog(
            recorder: recorder,
            send: (bytes) async {
              expect(bytes, [1, 2]);
              sends++;
              throw StateError('Offline');
            },
          ),
        ),
      ),
    );
    expect(recorder.started, false);
    await tester.tap(find.text('Record'));
    await tester.pump();
    expect(recorder.started, true);
    expect(sends, 0);
    await tester.tap(find.text('Stop recording'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sends, 1);
    expect(
      find.text('Could not send. Your recording is ready to retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sends, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(recorder.disposed, true);
  });
  testWidgets(
    'backgrounding discards a recording and releases the microphone',
    (tester) async {
      final recorder = FakeRecorder();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => VoiceMessageDialog(
                  recorder: recorder,
                  send: (_) async => fail('Must not send on background'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Voice message'), findsNothing);
      expect(recorder.disposed, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/voice_recording.dart';
import 'package:trace/features/chat/presentation/audio_message.dart';

void main() {
  testWidgets(
    'downloads, pauses, resumes and replays without downloading again',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('trace-player-test-'),
      ))!;
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPathProvider(root.path);
      final messenger = tester.binding.defaultBinaryMessenger;
      const channel = MethodChannel('xyz.luan/audioplayers');
      final calls = <MethodCall>[];
      String? playerId;
      String? path;
      Future<void> emit(String event, [Object? value]) async {
        await messenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$playerId',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'event': event,
            'value': value,
          }),
          (_) {},
        );
      }

      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'create') {
          playerId = call.arguments['playerId'] as String;
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (_) async => null,
          );
        }
        if (call.method == 'setSourceUrl') {
          path = call.arguments['url'] as String;
          expect(await File(path!).exists(), isTrue);
          await emit('audio.onPrepared', true);
        }
        if (call.method == 'getDuration') return 1000;
        if (call.method == 'getCurrentPosition') return 0;
        return null;
      });
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global/events'),
          null,
        );
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$playerId'),
          null,
        );
        await root.delete(recursive: true);
      });
      var downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioMessage(
              name: 'voice-test.wav',
              load: () async {
                downloads++;
                return MatrixAttachmentData(
                  bytes: pcmToWav(Uint8List(3200), sampleRate: 16000),
                  name: 'voice-test.wav',
                  mimeType: 'audio/wav',
                );
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Play audio'));
        // Wait for real file IO and the native preparation handshake.
        for (
          var i = 0;
          i < 100 && !calls.any((c) => c.method == 'resume');
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Pause audio'), findsOneWidget);
      expect(
        calls
            .where((c) => c.method == 'setReleaseMode')
            .single
            .arguments['releaseMode'],
        'ReleaseMode.stop',
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Pause audio'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Play audio'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => emit('audio.onComplete'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Play audio'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Play audio'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Pause audio'), findsOneWidget);
      expect(downloads, 1);
      expect(calls.where((c) => c.method == 'resume').length, 3);
      expect(calls.where((c) => c.method == 'setSourceUrl').length, 1);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Pause audio'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 100 && await File(path!).exists(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await File(path!).exists(), isFalse);
      });
    },
  );
}

class _TemporaryPathProvider extends PathProviderPlatform {
  _TemporaryPathProvider(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

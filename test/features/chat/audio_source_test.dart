import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:trace/features/chat/application/audio_source.dart';
import 'package:trace/features/chat/application/voice_recording.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('trace-audio-test-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPathProvider(root.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = original;
    await root.delete(recursive: true);
  });

  test(
    'prepares playable bytes in a fresh cache and removes them on disposal',
    () async {
      final bytes = pcmToWav(Uint8List(3200), sampleRate: 16000);
      final audio = await PrivateAudioSource.create(bytes, 'audio/wav');
      final source = audio.source as DeviceFileSource;
      final file = File(source.path);
      expect(await file.readAsBytes(), bytes);
      expect(source.mimeType, 'audio/wav');
      expect(file.path, endsWith('.wav'));
      expect(file.parent.parent.path, root.path);

      final second = await PrivateAudioSource.create(bytes, 'audio/wav');
      expect((second.source as DeviceFileSource).path, isNot(source.path));
      await audio.dispose();
      expect(await file.parent.exists(), isFalse);
      expect(
        await File((second.source as DeviceFileSource).path).exists(),
        isTrue,
      );
      await audio.dispose();
      await second.dispose();
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('uses an MP3 extension for the standard audio/mpeg MIME type', () async {
    final audio = await PrivateAudioSource.create(
      Uint8List.fromList([1, 2]),
      'audio/mpeg',
    );
    expect((audio.source as DeviceFileSource).path, endsWith('.mp3'));
    await audio.dispose();
  });
}

class _TemporaryPathProvider extends PathProviderPlatform {
  _TemporaryPathProvider(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

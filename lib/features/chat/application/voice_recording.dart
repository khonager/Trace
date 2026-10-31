import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// PCM stays in memory until the user explicitly sends or discards the message.
abstract interface class VoiceRecorder {
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> dispose();
}

class VoiceRecording implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  static const sampleRate = 16000;
  static const maxBytes = sampleRate * 2 * 300;
  Object? _error;
  bool _disposed = false;
  Future<void>? _disposal;

  @override
  Future<void> start() async {
    _pcm.clear();
    _error = null;
    if (!await _recorder.hasPermission()) {
      throw StateError(
        'Microphone permission was denied. Enable it in system settings.',
      );
    }
    if (_disposed) throw StateError('Recording was canceled.');
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    if (_disposed) throw StateError('Recording was canceled.');
    _subscription = stream.listen((chunk) {
      if (_pcm.length + chunk.length <= maxBytes) _pcm.add(chunk);
    }, onError: (Object error) => _error = error);
  }

  @override
  Future<Uint8List> stop() async {
    await _recorder.stop();
    await _subscription?.cancel();
    if (_error != null) {
      throw StateError('Recording failed. Please record again.');
    }
    return pcmToWav(_pcm.takeBytes(), sampleRate: sampleRate);
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    return _disposal ??= _dispose();
  }

  Future<void> _dispose() async {
    await _subscription?.cancel();
    await _recorder.dispose();
    _pcm.clear();
  }
}

Uint8List pcmToWav(Uint8List pcm, {required int sampleRate}) {
  if (pcm.isEmpty || pcm.length.isOdd) {
    throw StateError('No valid audio was recorded.');
  }
  final bytes = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}

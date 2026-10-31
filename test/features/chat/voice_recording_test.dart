import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/application/voice_recording.dart';

void main() {
  test('encodes mono 16 bit PCM as a playable WAV container', () {
    final pcm = Uint8List.fromList([0, 0, 255, 127, 0, 128]);
    final wav = pcmToWav(pcm, sampleRate: 16000);
    final header = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint32(4, Endian.little), wav.length - 8);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });
  test('rejects empty or incomplete samples', () {
    expect(() => pcmToWav(Uint8List(0), sampleRate: 16000), throwsStateError);
    expect(() => pcmToWav(Uint8List(1), sampleRate: 16000), throwsStateError);
  });
}

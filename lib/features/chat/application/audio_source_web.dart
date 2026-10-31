import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class PrivateAudioSource {
  PrivateAudioSource._(this.source);
  final Source source;
  static Future<PrivateAudioSource> create(
    Uint8List bytes,
    String mimeType,
  ) async => PrivateAudioSource._(BytesSource(bytes, mimeType: mimeType));
  Future<void> dispose() async {}
}

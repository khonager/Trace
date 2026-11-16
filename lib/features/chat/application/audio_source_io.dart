import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Own the temporary file rather than leaving decrypted plugin caches behind.
class PrivateAudioSource {
  PrivateAudioSource._(this.source, this._directory);
  final Source source;
  final Directory _directory;
  static Future<PrivateAudioSource> create(
    Uint8List bytes,
    String mimeType,
  ) async {
    final root = await getTemporaryDirectory();
    final directory = await Directory('${root.path}/trace-audio-').createTemp();
    try {
      final ext = mimeType.contains('wav')
          ? 'wav'
          : mimeType.contains('ogg')
          ? 'ogg'
          : mimeType.contains('mp3')
          ? 'mp3'
          : mimeType.contains('m4a') || mimeType.contains('mp4')
          ? 'm4a'
          : 'wav';
      final file = File('${directory.path}/audio.$ext');
      await file.writeAsBytes(bytes, flush: true);
      return PrivateAudioSource._(
        DeviceFileSource(file.path, mimeType: mimeType),
        directory,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'attachment_picker.dart';
import 'package:pasteboard/pasteboard.dart';

Future<List<String>> clipboardFilePaths() async {
  if (Platform.isIOS) return [];
  if (Platform.isAndroid) {
    return await const MethodChannel(
          'chat.trace/clipboard',
        ).invokeListMethod<String>('files') ??
        [];
  }
  return Pasteboard.files();
}

Future<List<ChatAttachment>> attachmentsFromPaths(List<String> paths) async {
  final result = <ChatAttachment>[];
  for (final value in paths) {
    final uri = Uri.tryParse(value);
    if (Platform.isAndroid && uri?.scheme == 'content') {
      final data = await const MethodChannel(
        'chat.trace/clipboard',
      ).invokeMapMethod<String, dynamic>('readContent', {'uri': value});
      final bytes = data?['bytes'] as Uint8List?;
      if (bytes == null) throw StateError('Clipboard file is unavailable.');
      result.add(
        ChatAttachment(
          name: data?['name'] as String? ?? 'attachment',
          readAsBytes: () async => bytes,
        ),
      );
    } else if (uri != null && (uri.scheme.isEmpty || uri.scheme == 'file')) {
      final file = uri.scheme == 'file' ? File.fromUri(uri) : File(value);
      if (await file.exists()) {
        result.add(
          ChatAttachment(
            name: path.basename(file.path),
            readAsBytes: file.readAsBytes,
          ),
        );
      }
    }
  }
  return result;
}

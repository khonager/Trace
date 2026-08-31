import 'dart:io';

import 'package:trace/features/chat/application/attachment_picker.dart';

Future<AttachmentPickerFallbackResult> pickChatAttachmentFallback() async {
  if (!Platform.isLinux) {
    return const AttachmentPickerFallbackResult.unavailable();
  }

  late final ProcessResult result;
  try {
    result = await Process.run('zenity', [
      '--file-selection',
      '--title=Add an attachment',
    ]);
  } on ProcessException {
    return const AttachmentPickerFallbackResult.unavailable();
  }

  // Zenity uses exit code 1 when the user closes or cancels the chooser.
  if (result.exitCode == 1) {
    return const AttachmentPickerFallbackResult.handled(null);
  }
  if (result.exitCode != 0) {
    final detail = (result.stderr as String).trim();
    throw Exception(
      detail.isEmpty
          ? 'The Linux file chooser exited with code ${result.exitCode}.'
          : detail,
    );
  }

  final selectedPath = (result.stdout as String).trim();
  if (selectedPath.isEmpty) {
    return const AttachmentPickerFallbackResult.handled(null);
  }
  final file = File(selectedPath);
  return AttachmentPickerFallbackResult.handled(
    ChatAttachment(
      name: file.uri.pathSegments.last,
      readAsBytes: file.readAsBytes,
    ),
  );
}

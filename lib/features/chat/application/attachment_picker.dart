import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:trace/features/chat/application/attachment_picker_fallback_stub.dart'
    if (dart.library.io) 'attachment_picker_fallback_io.dart';

/// Opens the platform file chooser, with a Linux desktop fallback for systems
/// whose XDG portal does not expose the FileChooser interface.
Future<ChatAttachment?> pickChatAttachment() async {
  try {
    final file = await FilePicker.pickFile(dialogTitle: 'Add an attachment');
    return file == null ? null : ChatAttachment.fromPlatformFile(file);
  } catch (error, stackTrace) {
    final fallback = await pickChatAttachmentFallback();
    if (fallback.available) return fallback.file;
    Error.throwWithStackTrace(error, stackTrace);
  }
}

final class ChatAttachment {
  const ChatAttachment({required this.name, required this.readAsBytes});

  factory ChatAttachment.fromPlatformFile(PlatformFile file) =>
      ChatAttachment(name: file.name, readAsBytes: file.readAsBytes);

  final String name;
  final Future<Uint8List> Function() readAsBytes;

  String? get extension {
    final separator = name.lastIndexOf('.');
    if (separator <= 0 || separator == name.length - 1) return null;
    return name.substring(separator + 1);
  }
}

final class AttachmentPickerFallbackResult {
  const AttachmentPickerFallbackResult.unavailable()
    : available = false,
      file = null;

  const AttachmentPickerFallbackResult.handled(this.file) : available = true;

  final bool available;
  final ChatAttachment? file;
}

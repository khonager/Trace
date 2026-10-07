import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:trace/features/chat/application/attachment_picker_fallback_stub.dart'
    if (dart.library.io) 'attachment_picker_fallback_io.dart';

/// Opens the platform file chooser, with a Linux desktop fallback for systems
/// whose XDG portal does not expose the FileChooser interface.
Future<ChatAttachment?> pickChatAttachment({
  FileType type = FileType.any,
  String dialogTitle = 'Add an attachment',
  bool preferLinuxChooser = false,
}) async {
  if (preferLinuxChooser) {
    try {
      final fallback = await pickChatAttachmentFallback(
        dialogTitle: dialogTitle,
      );
      if (fallback.available) return fallback.file;
    } catch (_) {
      // Try the platform chooser if Zenity cannot start in this environment.
    }
  }
  try {
    final file = await FilePicker.pickFile(
      type: type,
      dialogTitle: dialogTitle,
    );
    return file == null ? null : ChatAttachment.fromPlatformFile(file);
  } catch (error, stackTrace) {
    final fallback = await pickChatAttachmentFallback(dialogTitle: dialogTitle);
    if (fallback.available) return fallback.file;
    Error.throwWithStackTrace(error, stackTrace);
  }
}

/// Opens the Android system photo picker when available, directly into photos.
Future<ChatAttachment?> pickChatPhoto() async {
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
  final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
  return photo == null
      ? null
      : ChatAttachment(name: photo.name, readAsBytes: photo.readAsBytes);
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

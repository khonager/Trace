import 'package:pasteboard/pasteboard.dart';
import 'attachment_picker.dart';
import 'clipboard_files_stub.dart'
    if (dart.library.io) 'clipboard_files_io.dart';

Future<List<ChatAttachment>> readClipboardAttachments() async {
  final files = await clipboardFilePaths();
  final attachments = await attachmentsFromPaths(files);
  if (attachments.isNotEmpty) return attachments;
  final image = await Pasteboard.image;
  if (image == null || image.isEmpty) return [];
  return [
    ChatAttachment(
      name:
          'pasted-image.${image.length >= 3 && image[0] == 0xff && image[1] == 0xd8
              ? 'jpg'
              : image.length >= 3 && image[0] == 0x47 && image[1] == 0x49
              ? 'gif'
              : image.length >= 12 && image[8] == 0x57 && image[9] == 0x45
              ? 'webp'
              : 'png'}',
      readAsBytes: () async => image,
    ),
  ];
}

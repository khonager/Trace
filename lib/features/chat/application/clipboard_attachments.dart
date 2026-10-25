import 'package:pasteboard/pasteboard.dart';
import 'attachment_picker.dart';
import 'clipboard_files_stub.dart'
    if (dart.library.io) 'clipboard_files_io.dart';

Future<List<ChatAttachment>> readClipboardAttachments() async {
  final files = await Pasteboard.files();
  final attachments = await attachmentsFromPaths(files);
  if (attachments.isNotEmpty) return attachments;
  final image = await Pasteboard.image;
  if (image == null || image.isEmpty) return [];
  return [
    ChatAttachment(name: 'pasted-image.png', readAsBytes: () async => image),
  ];
}

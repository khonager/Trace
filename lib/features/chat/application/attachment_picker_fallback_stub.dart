import 'package:trace/features/chat/application/attachment_picker.dart';

Future<AttachmentPickerFallbackResult> pickChatAttachmentFallback() async =>
    const AttachmentPickerFallbackResult.unavailable();

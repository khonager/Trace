import 'package:trace/features/chat/application/attachment_picker.dart';

Future<AttachmentPickerFallbackResult> pickChatAttachmentFallback({
  required String dialogTitle,
}) async => const AttachmentPickerFallbackResult.unavailable();

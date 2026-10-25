import 'package:flutter/widgets.dart';
import 'attachment_picker.dart';

class PendingAttachments extends ChangeNotifier {
  final Map<String, List<ChatAttachment>> _rooms = {};
  List<ChatAttachment> forRoom(String room) =>
      List.unmodifiable(_rooms[room] ?? []);
  void add(String room, ChatAttachment attachment) {
    (_rooms[room] ??= []).add(attachment);
    notifyListeners();
  }

  void remove(String room, ChatAttachment attachment) {
    _rooms[room]?.remove(attachment);
    notifyListeners();
  }
}

class PendingAttachmentScope extends InheritedNotifier<PendingAttachments> {
  const PendingAttachmentScope({
    super.key,
    required PendingAttachments store,
    required super.child,
  }) : super(notifier: store);
  static PendingAttachments of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PendingAttachmentScope>()!
      .notifier!;
}

import 'dart:typed_data';

/// Protocol-neutral boundary around the selected Matrix SDK.
///
/// Widgets and product features only consume the immutable Trace models in
/// this file. This keeps the SDK replaceable and makes the UI straightforward
/// to test with a fake client.
abstract interface class MatrixClientPort {
  MatrixClientSnapshot get current;

  Stream<MatrixClientSnapshot> get snapshots;

  Stream<MatrixVerificationPort> get verificationRequests;

  Future<void> initialize();

  Future<void> login(MatrixLoginRequest request);

  Future<Uri> createSsoLoginUrl({
    required Uri homeserver,
    required Uri callback,
  });

  Future<void> logout();

  Future<MatrixTimelinePort> openTimeline(String roomId);

  Future<void> sendText({
    required String roomId,
    required String body,
    String? replyToEventId,
  });

  Future<void> editMessage({
    required String roomId,
    required String eventId,
    required String body,
  });

  Future<void> react({
    required String roomId,
    required String eventId,
    required String emoji,
  });

  Future<void> sendFile({
    required String roomId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<void> setTyping(String roomId, bool typing);

  Future<void> markRead(String roomId);

  Future<List<MatrixUser>> searchUsers(String query);

  Future<List<MatrixMessageSearchResult>> searchMessages(String query);

  Future<String> startDirectChat(String userId);

  Future<String> joinRoom(String roomIdOrAlias);

  Future<String> createSavedMessagesRoom();

  Future<String> createGroup({
    required String name,
    List<String> invitees = const [],
  });

  Future<void> acceptInvite(String roomId);

  Future<void> declineInvite(String roomId);

  Future<void> leaveRoom(String roomId);

  Future<void> setRoomPinned(
    String roomId, {
    required bool pinned,
    double? order,
  });

  Future<void> setSpaceOrder(List<String> spaceIds);

  Future<String> initializeRecovery(String passphrase);

  Future<void> restoreRecovery(String passphraseOrRecoveryKey);

  Future<List<MatrixDevice>> getDevices();

  Future<MatrixVerificationPort> startDeviceVerification(String deviceId);

  Future<void> setForeground(bool foreground);

  Future<void> close();
}

abstract interface class MatrixTimelinePort {
  List<MatrixMessage> get current;

  Stream<List<MatrixMessage>> get updates;

  bool get canLoadOlder;

  Future<void> loadOlder();

  Future<void> retry(String eventId);

  Future<void> requestKey(String eventId);

  /// Downloads and decrypts media belonging to a timeline event.
  ///
  /// Image previews request a thumbnail when the event provides one and fall
  /// back to the original attachment otherwise.
  Future<MatrixAttachmentData> downloadAttachment(
    String eventId, {
    bool thumbnail = false,
  });

  Future<void> redact(String eventId, {String? reason});

  Future<void> close();
}

abstract interface class MatrixVerificationPort {
  MatrixVerificationSnapshot get current;

  Stream<MatrixVerificationSnapshot> get updates;

  Future<void> acceptRequest();

  Future<void> startEmojiComparison();

  Future<void> confirmMatch();

  Future<void> reject({bool mismatch = false});

  Future<void> continueWithRecovery(String recoveryKeyOrPassphrase);

  Future<void> close();
}

sealed class MatrixLoginRequest {
  const MatrixLoginRequest({required this.homeserver});

  final Uri homeserver;
}

final class PasswordLoginRequest extends MatrixLoginRequest {
  const PasswordLoginRequest({
    required super.homeserver,
    required this.user,
    required this.password,
  });

  final String user;
  final String password;
}

final class SsoLoginRequest extends MatrixLoginRequest {
  const SsoLoginRequest({required super.homeserver, required this.loginToken});

  final String loginToken;
}

enum MatrixConnectionPhase {
  starting,
  signedOut,
  syncing,
  ready,
  reconnecting,
  softLoggedOut,
  error,
}

enum MatrixRoomMembership { joined, invited, left }

enum MatrixMessageDelivery { sending, sent, failed, synced }

enum MatrixMessageKind { text, image, video, audio, file }

enum MatrixVerificationPhase {
  requested,
  chooseMethod,
  waiting,
  compare,
  needsRecovery,
  done,
  cancelled,
  error,
}

final class MatrixClientSnapshot {
  const MatrixClientSnapshot({
    required this.phase,
    this.account,
    this.rooms = const [],
    this.error,
    this.spaceOrder = const [],
  });

  const MatrixClientSnapshot.starting()
    : this(phase: MatrixConnectionPhase.starting);

  final MatrixConnectionPhase phase;
  final MatrixAccount? account;
  final List<MatrixRoom> rooms;
  final String? error;
  final List<String> spaceOrder;

  bool get isLoggedIn => account != null;
}

final class MatrixAccount {
  const MatrixAccount({
    required this.userId,
    required this.displayName,
    required this.homeserver,
    this.deviceId,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final Uri homeserver;
  final String? deviceId;
  final Uri? avatarUrl;
}

final class MatrixRoom {
  const MatrixRoom({
    required this.id,
    required this.name,
    required this.preview,
    required this.timestamp,
    required this.membership,
    required this.unreadCount,
    required this.encrypted,
    required this.isDirect,
    this.directUserId,
    this.avatarUrl,
    this.typingUsers = const [],
    this.isSpace = false,
    this.childRoomIds = const [],
    this.isPinned = false,
    this.pinOrder,
  });

  final String id;
  final String name;
  final String preview;
  final DateTime timestamp;
  final MatrixRoomMembership membership;
  final int unreadCount;
  final bool encrypted;
  final bool isDirect;
  final String? directUserId;
  final Uri? avatarUrl;
  final List<String> typingUsers;
  final bool isSpace;
  final List<String> childRoomIds;
  final bool isPinned;
  final double? pinOrder;
}

/// Returns chat rooms in a selected Matrix space, including nested spaces.
/// Space rooms themselves are containers and are never returned as chats.
List<MatrixRoom> matrixChatRoomsForSpace(
  List<MatrixRoom> rooms, {
  String? spaceId,
}) {
  if (spaceId == null) {
    final chats = rooms.where((room) => !room.isSpace).toList(growable: false);
    chats.sort((a, b) {
      final aPinned = a.isDirect && a.isPinned;
      final bPinned = b.isDirect && b.isPinned;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      if (aPinned) {
        final order = (a.pinOrder ?? 1).compareTo(b.pinOrder ?? 1);
        if (order != 0) return order;
      }
      return b.timestamp.compareTo(a.timestamp);
    });
    return chats;
  }
  final byId = {for (final room in rooms) room.id: room};
  final visibleRooms = <MatrixRoom>[];
  final visibleIds = <String>{};
  final visitedSpaces = <String>{};

  void visit(String id) {
    final room = byId[id];
    if (room == null) return;
    if (!room.isSpace) {
      if (visibleIds.add(id)) visibleRooms.add(room);
      return;
    }
    if (!visitedSpaces.add(id)) return;
    for (final childId in room.childRoomIds) {
      visit(childId);
    }
  }

  visit(spaceId);
  return visibleRooms;
}

final class MatrixMessage {
  const MatrixMessage({
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.timestamp,
    required this.sentByMe,
    required this.delivery,
    this.kind = MatrixMessageKind.text,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSize,
    this.senderAvatarUrl,
    this.isSystem = false,
    this.isUndecryptable = false,
    this.canRequestKey = false,
  });

  final String eventId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime timestamp;
  final bool sentByMe;
  final MatrixMessageDelivery delivery;
  final MatrixMessageKind kind;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSize;
  final Uri? senderAvatarUrl;
  final bool isSystem;
  final bool isUndecryptable;
  final bool canRequestKey;
}

final class MatrixAttachmentData {
  const MatrixAttachmentData({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

final class MatrixUser {
  const MatrixUser({required this.userId, this.displayName, this.avatarUrl});

  final String userId;
  final String? displayName;
  final Uri? avatarUrl;
}

final class MatrixDevice {
  const MatrixDevice({
    required this.id,
    required this.name,
    required this.isCurrent,
    required this.verified,
    this.lastSeen,
  });

  final String id;
  final String name;
  final bool isCurrent;
  final bool verified;
  final DateTime? lastSeen;
}

final class MatrixVerificationEmoji {
  const MatrixVerificationEmoji({required this.symbol, required this.name});

  final String symbol;
  final String name;
}

final class MatrixVerificationSnapshot {
  const MatrixVerificationSnapshot({
    required this.phase,
    required this.userId,
    this.deviceId,
    this.emojis = const [],
    this.numbers = const [],
    this.message,
  });

  final MatrixVerificationPhase phase;
  final String userId;
  final String? deviceId;
  final List<MatrixVerificationEmoji> emojis;
  final List<int> numbers;
  final String? message;
}

final class MatrixMessageSearchResult {
  const MatrixMessageSearchResult({
    required this.roomId,
    required this.roomName,
    required this.eventId,
    required this.senderName,
    required this.body,
    required this.timestamp,
  });

  final String roomId;
  final String roomName;
  final String eventId;
  final String senderName;
  final String body;
  final DateTime timestamp;
}

final class MatrixRoomNotFoundException implements Exception {
  const MatrixRoomNotFoundException(this.roomId);

  final String roomId;

  @override
  String toString() => 'No Matrix room is cached for $roomId.';
}

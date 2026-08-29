import 'package:trace/core/policy/user_selection_policy.dart';

/// Sender-owned policy for broadcasting an unsent draft.
final class LiveTypingPolicy {
  const LiveTypingPolicy({required this.recipients});

  final UserSelectionPolicy recipients;

  bool broadcastsTo(String matrixUserId) => recipients.allows(matrixUserId);
}

/// An online-only draft update. Transports must never add this to room history.
final class LiveTypingUpdate {
  const LiveTypingUpdate({
    required this.sessionId,
    required this.sequence,
    required this.text,
    required this.expiresAt,
  });

  final String sessionId;
  final int sequence;
  final String text;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

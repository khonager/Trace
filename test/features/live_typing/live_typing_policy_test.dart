import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/policy/user_selection_policy.dart';
import 'package:trace/features/live_typing/domain/live_typing_policy.dart';

void main() {
  test('expired updates cannot be treated as current drafts', () {
    final now = DateTime.utc(2026, 8, 29, 12);
    final update = LiveTypingUpdate(
      sessionId: 'draft-1',
      sequence: 3,
      text: 'unfinished',
      expiresAt: now.subtract(const Duration(milliseconds: 1)),
    );

    expect(update.isExpiredAt(now), isTrue);
  });

  test('sender controls who receives live typing', () {
    const policy = LiveTypingPolicy(
      recipients: UserSelectionPolicy(
        enabled: true,
        mode: UserSelectionMode.only,
        userIds: {'@friend:example.org'},
      ),
    );

    expect(policy.broadcastsTo('@friend:example.org'), isTrue);
    expect(policy.broadcastsTo('@coworker:example.org'), isFalse);
  });
}

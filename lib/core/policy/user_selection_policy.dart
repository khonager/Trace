enum UserSelectionMode { everyoneExcept, only }

/// A reusable sender-controlled allow/deny policy based on Matrix user IDs.
final class UserSelectionPolicy {
  const UserSelectionPolicy({
    required this.enabled,
    required this.mode,
    this.userIds = const <String>{},
  });

  const UserSelectionPolicy.disabled()
    : enabled = false,
      mode = UserSelectionMode.only,
      userIds = const <String>{};

  final bool enabled;
  final UserSelectionMode mode;
  final Set<String> userIds;

  bool allows(String matrixUserId) {
    if (!enabled) return false;

    return switch (mode) {
      UserSelectionMode.everyoneExcept => !userIds.contains(matrixUserId),
      UserSelectionMode.only => userIds.contains(matrixUserId),
    };
  }
}

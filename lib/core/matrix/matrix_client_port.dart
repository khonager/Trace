/// Stable boundary around whichever Matrix SDK is selected.
///
/// The concrete SDK is intentionally not exposed to product features. This
/// keeps licensing and SDK migration decisions out of the application layer.
abstract interface class MatrixClientPort {
  Stream<MatrixSyncUpdate> get updates;

  Future<void> login(MatrixLoginRequest request);

  Future<void> logout();

  Future<void> sendText({required String roomId, required String body});
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
  const SsoLoginRequest({required super.homeserver});
}

final class MatrixSyncUpdate {
  const MatrixSyncUpdate({required this.nextBatchToken});

  final String nextBatchToken;
}

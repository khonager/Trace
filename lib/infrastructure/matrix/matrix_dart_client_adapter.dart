import 'package:flutter/foundation.dart' show compute;
import 'package:matrix/matrix.dart' as matrix;
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/infrastructure/matrix/matrix_crypto_bootstrap.dart';

/// Creates the selected Matrix Dart SDK client around an injected database.
///
/// Database construction stays outside this adapter because Trace requires an
/// encrypted platform-specific store. Call [matrix.Client.init] on the result
/// to restore a persisted session before presenting the application.
matrix.Client createMatrixDartClient({
  required matrix.DatabaseApi database,
  String clientName = 'Trace',
}) {
  return matrix.Client(
    clientName,
    database: database,
    supportedLoginTypes: const {
      matrix.AuthenticationTypes.password,
      matrix.AuthenticationTypes.sso,
      matrix.AuthenticationTypes.token,
    },
    nativeImplementations: matrix.NativeImplementationsIsolate(
      compute,
      vodozemacInit: initializeMatrixCrypto,
    ),
  );
}

/// Matrix implementation of the protocol-neutral application port.
///
/// SDK models stop here; features only receive Trace's own models.
final class MatrixDartClientAdapter implements MatrixClientPort {
  MatrixDartClientAdapter(this._client);

  final matrix.Client _client;

  @override
  Stream<MatrixSyncUpdate> get updates => _client.onSync.stream.map(
    (update) => MatrixSyncUpdate(nextBatchToken: update.nextBatch),
  );

  @override
  Future<void> login(MatrixLoginRequest request) async {
    await _client.checkHomeserver(request.homeserver);

    switch (request) {
      case PasswordLoginRequest():
        await _client.login(
          matrix.AuthenticationTypes.password,
          identifier: matrix.AuthenticationUserIdentifier(user: request.user),
          password: request.password,
          initialDeviceDisplayName: 'Trace',
        );
      case SsoLoginRequest():
        await _client.login(
          matrix.AuthenticationTypes.token,
          token: request.loginToken,
          initialDeviceDisplayName: 'Trace',
        );
    }
  }

  @override
  Future<void> logout() => _client.logout();

  @override
  Future<void> sendText({required String roomId, required String body}) async {
    final room = _client.getRoomById(roomId);
    if (room == null) {
      throw MatrixRoomNotFoundException(roomId);
    }
    await room.sendTextEvent(body);
  }

  @override
  Future<void> close() => _client.dispose();
}

final class MatrixRoomNotFoundException implements Exception {
  const MatrixRoomNotFoundException(this.roomId);

  final String roomId;

  @override
  String toString() => 'No joined Matrix room is cached for $roomId.';
}

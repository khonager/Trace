import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/encryption.dart' as crypto;
import 'package:matrix/matrix.dart' as matrix;
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/infrastructure/matrix/matrix_dart_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late MatrixDartClientAdapter adapter;

  setUp(() async {
    client = _Client();
    adapter = MatrixDartClientAdapter(client);
    await adapter.initialize();
  });
  tearDown(() => adapter.close());

  for (final methods in [
    ['m.sas.v1'],
    ['m.sas.v1', 'm.qr_code.show.v1', 'm.qr_code.scan.v1', 'm.reciprocate.v1'],
  ]) {
    test('surfaces standard incoming request with methods $methods', () async {
      final incoming = adapter.verificationRequests.first;
      await client.receiveRequest(methods);
      final verification = await incoming;
      expect(verification.current.phase, MatrixVerificationPhase.requested);
      expect(verification.current.deviceId, 'WEB');
      expect(client.sent, isEmpty);

      // Verify in settings must resume the incoming transaction, not cancel
      // the peer's dialog by opening a competing transaction.
      expect(await adapter.startDeviceVerification('WEB'), same(verification));
      expect(client.sent, isEmpty);
      await verification.acceptRequest();
      expect(client.sent.single.type, matrix.EventTypes.KeyVerificationReady);
      expect(client.sent.single.content['transaction_id'], 'remote-request');
      expect(client.sent.single.content['methods'], ['m.sas.v1']);

      await verification.startEmojiComparison();
      final request = client.encryption.keyVerificationManager.getRequest(
        'remote-request',
      )!;
      expect(request.startedVerification, isTrue);
      expect(client.sent.last.type, matrix.EventTypes.KeyVerificationStart);
      // A stale button must not send a second start after the state advances.
      await verification.startEmojiComparison();
      expect(client.sent.length, 2);
    });
  }

  test('repeated outgoing starts share one transaction', () async {
    final requests = await Future.wait([
      adapter.startDeviceVerification('WEB'),
      adapter.startDeviceVerification('WEB'),
    ]);
    expect(requests.first, same(requests.last));
    expect(client.sent.length, 1);
    expect(client.sent.single.type, matrix.EventTypes.KeyVerificationRequest);
    await requests.first.reject();
    final replacement = await adapter.startDeviceVerification('WEB');
    expect(replacement, isNot(same(requests.first)));
    expect(client.sent.last.type, matrix.EventTypes.KeyVerificationRequest);
  });

  test('resuming a request does not queue a duplicate dialog', () async {
    final controller = MatrixSessionController(adapter);
    await controller.initialize();
    addTearDown(controller.dispose);
    await client.receiveRequest(['m.sas.v1']);
    await Future<void>.delayed(Duration.zero);
    final incoming = controller.activeVerification;
    expect(incoming, isNotNull);
    await controller.startDeviceVerification('WEB');
    expect(controller.activeVerification, same(incoming));
    await incoming!.reject();
    await controller.dismissVerification();
    expect(controller.activeVerification, isNull);
  });
}

// Use the real SDK verification state machine and adapter. Only persistence,
// login and transport are replaced; no network account or native crypto is
// needed to test request/ready/start negotiation.
class _Client extends matrix.Client {
  _Client() : super('Trace-test', database: _Database()) {
    verificationMethods = createMatrixDartClient(
      database: _Database(),
    ).verificationMethods;
    final keys = matrix.DeviceKeysList(userID, this);
    keys.deviceKeys['WEB'] = _Device(this);
    userDeviceKeys[userID] = keys;
  }

  @override
  String get userID => '@alice:example.org';
  @override
  String get deviceID => 'TRACE';
  @override
  late final crypto.Encryption encryption = encryptionFor(this);
  static crypto.Encryption encryptionFor(matrix.Client client) =>
      crypto.Encryption(client: client);

  final sent = <({String type, Map<String, dynamic> content})>[];

  Future<void> receiveRequest(List<String> methods) =>
      encryption.keyVerificationManager.handleToDeviceEvent(
        matrix.ToDeviceEvent.fromJson({
          'sender': userID,
          'type': matrix.EventTypes.KeyVerificationRequest,
          'content': {
            'from_device': 'WEB',
            'transaction_id': 'remote-request',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'methods': methods,
          },
        }),
      );

  @override
  Future<void> sendToDeviceEncrypted(
    List<matrix.DeviceKeys> deviceKeys,
    String eventType,
    Map<String, dynamic> message, {
    String? messageId,
    bool onlyVerified = false,
  }) async {
    sent.add((type: eventType, content: Map.of(message)));
  }

  @override
  Future<void> init({
    String? newToken,
    DateTime? newTokenExpiresAt,
    String? newRefreshToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
    String? newOidcClientId,
    bool waitForFirstSync = true,
    bool waitUntilLoadCompletedLoaded = true,
    void Function()? onMigration,
    void Function(matrix.InitState)? onInitStateChanged,
  }) async {}

  @override
  Future<void> dispose({bool closeDatabase = true}) async {
    encryption.keyVerificationManager.dispose();
  }
}

class _Device extends matrix.DeviceKeys {
  _Device(matrix.Client client)
    : super.fromJson({
        'user_id': client.userID,
        'device_id': 'WEB',
        'algorithms': <String>[],
        'keys': <String, String>{},
      }, client);

  @override
  bool get isValid => true;
}

class _Database implements matrix.DatabaseApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

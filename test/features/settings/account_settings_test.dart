import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/settings/presentation/settings_page.dart';

void main() {
  late _AccountClient client;
  late MatrixSessionController controller;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    client = _AccountClient();
    controller = MatrixSessionController(client);
    await controller.initialize();
  });

  tearDown(() {
    controller.dispose();
    client.disposeStream();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('account card copies the Matrix ID and edits the display name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('matrix-account-profile')));
    await tester.pump();
    expect(find.text('Matrix ID copied.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('matrix-display-name-field')),
      'New name',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(client.updatedDisplayName, 'New name');
  });

  testWidgets('another session can be removed after password confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: controller)),
      ),
    );

    await tester.tap(find.text('Devices and sessions'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('device-actions-OLD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('device-actions-OLD')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove session').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove session'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm your password'), findsOneWidget);
    expect(client.removalAttempts, [null]);
    await tester.enterText(find.byType(TextField).last, 'correct horse');
    await tester.pump();
    await tester.tap(find.byKey(const Key('secret-dialog-action')));
    await tester.pumpAndSettle();

    expect(client.removalAttempts, [null, 'correct horse']);
    expect(client.removedDeviceId, 'OLD');
    expect(client.removalPassword, 'correct horse');
  });

  testWidgets(
    'own avatar uses authenticated Matrix media and opens full size',
    (tester) async {
      client.avatarUri = Uri.parse('mxc://example.org/avatar');
      client.publish();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsPage(controller: controller)),
        ),
      );
      await tester.pump();

      expect(client.thumbnailRequests, 1);
      await tester.tap(find.byKey(const Key('open-own-profile-picture')));
      await tester.pump();
      await tester.pump();

      expect(client.originalRequests, 1);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const Key('download-own-profile-picture')),
        findsOneWidget,
      );
    },
  );
}

final class _AccountClient
    implements MatrixClientPort, MatrixAccountManagementPort {
  Uri? avatarUri;
  int thumbnailRequests = 0;
  int originalRequests = 0;
  final StreamController<MatrixClientSnapshot> _snapshotController =
      StreamController.broadcast(sync: true);

  void publish() => _snapshotController.add(current);
  void disposeStream() => _snapshotController.close();

  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    account: MatrixAccount(
      userId: '@alice:example.org',
      displayName: 'Alice',
      homeserver: Uri.parse('https://example.org'),
      deviceId: 'CURRENT',
      avatarMediaUri: avatarUri,
    ),
  );

  String? updatedDisplayName;
  String? removedDeviceId;
  String? removalPassword;
  final List<String?> removalAttempts = [];

  @override
  Future<Uint8List> downloadMediaThumbnail(
    Uri mxcUri, {
    int width = 96,
    int height = 96,
  }) async {
    thumbnailRequests++;
    return _onePixelPng;
  }

  @override
  Future<Uint8List> downloadMedia(Uri mxcUri) async {
    originalRequests++;
    return _onePixelPng;
  }

  @override
  Stream<MatrixClientSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      const Stream.empty();

  @override
  Stream<MatrixRoomKeyRequestPort> get roomKeyRequests => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<MatrixDevice>> getDevices() async => const [
    MatrixDevice(
      id: 'CURRENT',
      name: 'This device',
      isCurrent: true,
      verified: true,
    ),
    MatrixDevice(
      id: 'OLD',
      name: 'Old browser',
      isCurrent: false,
      verified: false,
    ),
  ];

  @override
  Future<void> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarName,
    String? avatarMimeType,
    bool removeAvatar = false,
  }) async {
    updatedDisplayName = displayName;
  }

  @override
  Future<void> removeDevice(String deviceId, {String? password}) async {
    removalAttempts.add(password);
    if (password == null) {
      throw const MatrixReauthenticationRequiredException();
    }
    removedDeviceId = deviceId;
    removalPassword = password;
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _onePixelPng = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  162,
  200,
  84,
  165,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

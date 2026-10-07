import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/attachment_picker.dart';
import 'package:trace/features/settings/application/appearance_settings.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/application/profile_image_store.dart';
import 'package:trace/features/settings/presentation/profile_picture_editor.dart';
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

      expect(client.originalRequests, 1);
      await tester.tap(find.byKey(const Key('open-own-profile-picture')));
      await tester.pump();
      await tester.pump();

      expect(client.originalRequests, 2);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const Key('download-own-profile-picture')),
        findsOneWidget,
      );
    },
  );

  testWidgets('appearance sliders and switches update on the current page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appearance = AppearanceSettings();
    addTearDown(appearance.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(controller: controller, appearance: appearance),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('appearance-settings')));
    await tester.pumpAndSettle();

    final stickerSlider = find.descendant(
      of: find.byKey(const Key('sticker-size-slider')),
      matching: find.byType(Slider),
    );
    expect(tester.widget<Slider>(stickerSlider).value, 144);
    await tester.drag(stickerSlider, const Offset(90, 0));
    await tester.pump();
    expect(tester.widget<Slider>(stickerSlider).value, greaterThan(144));
    expect(find.text('${appearance.stickerSize.round()} px'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-background-switch')));
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('profile-background-switch')),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('background-blur-slider')), findsNothing);

    await tester.ensureVisible(find.text('Restore Trace defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Trace defaults'));
    await tester.pump();
    expect(tester.widget<Slider>(stickerSlider).value, 144);
    expect(find.byKey(const Key('background-blur-slider')), findsOneWidget);
  });

  testWidgets('profile editor applies gestures without focusing the name', (
    tester,
  ) async {
    client.avatarUri = Uri.parse('mxc://example.org/avatar');
    client.pictureBytes = (await tester.runAsync(_twoColorImage))!;
    client.publish();
    final imageStore = _TestProfileImageStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            profileImageStore: imageStore,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final preview = find.byKey(const Key('profile-crop-preview'));
    expect(preview, findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('matrix-display-name-field')))
          .autofocus,
      isFalse,
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const Key('replace-profile-picture')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-profile-picture')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final area = find.byKey(const Key('profile-picture-gesture-area'));
    expect(area, findsOneWidget);
    final savePicture = find.byKey(const Key('save-profile-picture-edit'));
    expect(tester.widget<FilledButton>(savePicture).onPressed, isNotNull);
    expect(
      tester
          .widget<FilledButton>(savePicture)
          .style
          ?.backgroundColor
          ?.resolve({}),
      const Color(0xFF8B68E8),
    );
    final shapeToggle = find.byKey(const Key('profile-preview-shape-toggle'));
    expect(
      tester.widget<IconButton>(shapeToggle).tooltip,
      'Show square preview',
    );
    await tester.tap(shapeToggle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(shapeToggle).tooltip,
      'Show circular preview',
    );
    await tester.tap(shapeToggle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(shapeToggle).tooltip,
      'Show square preview',
    );
    await tester.drag(area, const Offset(25, 15));
    await tester.pump();
    final center = tester.getCenter(area);
    final first = await tester.startGesture(
      center + const Offset(-35, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(35, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(-20, -10));
    await second.moveBy(const Offset(20, 10));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.tap(find.byTooltip('Rotate right'));
    await tester.tap(find.byTooltip('Flip horizontally'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-profile-picture-edit')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-picture-editor')), findsNothing);
    expect(find.byKey(const Key('matrix-display-name-field')), findsNothing);
    expect(client.uploadedAvatar, isNotNull);
    expect(imageStore.written?.transform.offset, isNot(Offset.zero));
    expect(imageStore.written?.transform.scale, greaterThan(1));
    expect(
      imageStore.written?.transform.rotation,
      closeTo(math.pi / 2 + math.atan2(20, 110), .01),
    );
    expect(imageStore.written?.transform.flipHorizontal, isTrue);
  });

  testWidgets('PNG blur control appears only when the framing needs it', (
    tester,
  ) async {
    client.avatarUri = Uri.parse('mxc://example.org/avatar');
    client.pictureBytes = (await tester.runAsync(_twoColorImage))!;
    client.publish();
    final imageStore = _TestProfileImageStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            profileImageStore: imageStore,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-profile-picture')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final blurSwitch = find.byKey(const Key('profile-blur-background-switch'));
    final gestureArea = find.byKey(const Key('profile-picture-gesture-area'));
    final previewSize = tester.getSize(gestureArea);
    expect(blurSwitch, findsNothing);
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(blurSwitch, findsOneWidget);
    expect(tester.getSize(gestureArea), previewSize);
    expect(tester.widget<Switch>(blurSwitch).value, isFalse);
    await tester.tap(blurSwitch);
    await tester.pump();
    expect(tester.widget<Switch>(blurSwitch).value, isTrue);
    await tester.tap(find.byKey(const Key('save-profile-picture-edit')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(imageStore.written?.transform.blurBackground, isTrue);
  });

  testWidgets('preview shape control respects a phone camera inset', (
    tester,
  ) async {
    final source = (await tester.runAsync(_twoColorImage))!;
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 760),
            padding: EdgeInsets.only(top: 56),
          ),
          child: ProfilePictureEditor(
            source: source,
            initialTransform: const ProfileImageTransform(),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final shapeToggle = find.byKey(const Key('profile-preview-shape-toggle'));
    expect(tester.getTopLeft(shapeToggle).dy, greaterThanOrEqualTo(56));
    await tester.tap(shapeToggle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(shapeToggle).tooltip,
      'Show circular preview',
    );
  });

  testWidgets('a transparent PNG offers blur while leaving it off by default', (
    tester,
  ) async {
    final source = (await tester.runAsync(_transparentPngImage))!;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePictureEditor(
          source: source,
          initialTransform: const ProfileImageTransform(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final blurSwitch = find.byKey(const Key('profile-blur-background-switch'));
    expect(blurSwitch, findsOneWidget);
    expect(tester.widget<Switch>(blurSwitch).value, isFalse);
  });

  testWidgets('replacing a picture opens the editor and saves it directly', (
    tester,
  ) async {
    final source = (await tester.runAsync(_twoColorImage))!;
    var pickerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            profileImageStore: _TestProfileImageStore(),
            pickProfilePicture: () async {
              pickerCalls++;
              return ChatAttachment(
                name: 'profile.png',
                readAsBytes: () async => source,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-profile-picture')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(pickerCalls, 1);
    expect(find.byKey(const Key('profile-picture-editor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-profile-picture-edit')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(client.uploadedAvatar, isNotNull);
    expect(find.byKey(const Key('matrix-display-name-field')), findsNothing);
  });

  testWidgets('a failed picture chooser reports its error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            pickProfilePicture: () async => throw Exception('No chooser'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-profile-picture')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No chooser'), findsOneWidget);
  });

  testWidgets('reopening the editor keeps the uncropped source image', (
    tester,
  ) async {
    final source = (await tester.runAsync(_twoColorImage))!;
    final store = _TestProfileImageStore()..serveWritten = true;
    client.delayAvatarSnapshot = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            profileImageStore: store,
            pickProfilePicture: () async => ChatAttachment(
              name: 'source.png',
              readAsBytes: () async => source,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-profile-picture')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.tap(find.byKey(const Key('save-profile-picture-edit')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(store.written?.bytes, source);
    expect(store.writtenUri, client.pendingAvatarUri);
    expect(client.avatarUri, isNull);
    final firstScale = store.written!.transform.scale;
    expect(firstScale, greaterThan(1));

    client.applyPendingAvatar();
    await tester.pump();
    final requestsBeforeReopen = client.originalRequests;
    await tester.tap(find.byKey(const Key('edit-matrix-profile')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(store.readHits, greaterThan(0));
    expect(client.originalRequests, requestsBeforeReopen);
    await tester.tap(find.byKey(const Key('edit-profile-picture')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.tap(find.byKey(const Key('save-profile-picture-edit')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(store.written?.bytes, source);
    expect(store.written!.transform.scale, lessThan(firstScale));
  });
}

class _TestProfileImageStore extends ProfileImageStore {
  _TestProfileImageStore();

  ProfileImageSource? written;
  Uri? writtenUri;
  bool serveWritten = false;
  int readHits = 0;

  @override
  Future<ProfileImageSource?> read(String accountKey, Uri? avatarUri) async {
    if (serveWritten && avatarUri == writtenUri && written != null) {
      readHits++;
      return written;
    }
    return null;
  }

  @override
  Future<ProfileImageSource?> recover(
    String accountKey,
    Uri avatarUri,
    Uint8List avatarBytes,
  ) async => null;

  @override
  Future<void> write(
    String accountKey,
    Uri? avatarUri,
    ProfileImageSource source,
  ) async {
    written = source;
    writtenUri = avatarUri;
  }
}

final class _AccountClient
    implements MatrixClientPort, MatrixAccountManagementPort {
  Uri? avatarUri;
  int thumbnailRequests = 0;
  int originalRequests = 0;
  Uint8List pictureBytes = _onePixelPng;
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
  Uint8List? uploadedAvatar;
  int avatarUpdates = 0;
  bool delayAvatarSnapshot = false;
  Uri? pendingAvatarUri;

  void applyPendingAvatar() {
    avatarUri = pendingAvatarUri;
    pendingAvatarUri = null;
    publish();
  }

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
    return pictureBytes;
  }

  @override
  Future<Uint8List> downloadMedia(Uri mxcUri) async {
    originalRequests++;
    return pictureBytes;
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
  Future<Uri?> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarName,
    String? avatarMimeType,
    bool removeAvatar = false,
  }) async {
    updatedDisplayName = displayName;
    uploadedAvatar = avatarBytes;
    if (avatarBytes != null) {
      final uploadedUri = Uri.parse(
        'mxc://example.org/upload-${++avatarUpdates}',
      );
      pictureBytes = avatarBytes;
      if (delayAvatarSnapshot) {
        pendingAvatarUri = uploadedUri;
      } else {
        avatarUri = uploadedUri;
        publish();
      }
      return uploadedUri;
    } else if (removeAvatar) {
      avatarUri = null;
      publish();
    }
    return null;
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

Future<Uint8List> _twoColorImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 100, 100),
    Paint()..color = Colors.red,
  );
  canvas.drawRect(
    const Rect.fromLTWH(100, 0, 100, 100),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 100);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> _transparentPngImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(50, 50), 35, Paint()..color = Colors.red);
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

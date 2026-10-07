import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/application/profile_image_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reframing one rectangular source changes the square upload', () async {
    final source = await _twoColorSource();

    final left = await cropProfileImage(
      source,
      zoom: 1,
      horizontal: -1,
      vertical: 0,
      outputSize: 20,
    );
    final right = await cropProfileImage(
      source,
      zoom: 1,
      horizontal: 1,
      vertical: 0,
      outputSize: 20,
    );

    expect(left, isNot(equals(right)));
    expect(await _centerPixel(left), [244, 67, 54, 255]);
    expect(await _centerPixel(right), [33, 150, 243, 255]);
    expect(source, isA<Uint8List>());
  });

  test('drag and pinch keep the touched point anchored', () {
    final transformed = transformProfileGesture(
      start: const ProfileImageTransform(),
      startFocalPoint: const Offset(150, 100),
      focalPoint: const Offset(150, 100),
      gestureScale: 2,
      gestureRotation: math.pi / 2,
      viewportSize: 200,
    );
    expect(transformed.scale, 2);
    expect(transformed.rotation, closeTo(math.pi / 2, .001));
    expect(transformed.offset, const Offset(.25, -.5));
  });

  test(
    'zoomed-out and flipped output remains filled with image color',
    () async {
      final source = await _twoColorSource();
      final zoomedOut = await renderProfileImage(
        source,
        transform: const ProfileImageTransform(scale: .25),
        outputSize: 40,
      );
      final flipped = await renderProfileImage(
        source,
        transform: const ProfileImageTransform(flipHorizontal: true),
        outputSize: 40,
      );
      final left = await _pixelAt(flipped, 8, 20);
      final right = await _pixelAt(flipped, 32, 20);
      expect(left[2], greaterThan(left[0]));
      expect(right[0], greaterThan(right[2]));
      final backgroundLeft = await _pixelAt(zoomedOut, 0, 0);
      final backgroundRight = await _pixelAt(zoomedOut, 39, 39);
      expect(backgroundLeft[0], greaterThan(backgroundLeft[2]));
      expect(backgroundRight[2], greaterThan(backgroundRight[0]));
      expect(backgroundLeft[3], 255);
      expect(backgroundRight[3], 255);
    },
  );

  test('stored slider framing converts to the new transform', () async {
    final source = await _twoColorSource();
    final legacy = await cropProfileImage(
      source,
      zoom: 1.5,
      horizontal: 1,
      vertical: 0,
      outputSize: 40,
    );
    final transform = ProfileImageTransform.fromLegacy(
      const Size(200, 100),
      zoom: 1.5,
      horizontal: 1,
      vertical: 0,
    );
    final migrated = await renderProfileImage(
      source,
      transform: transform,
      outputSize: 40,
    );
    final oldCenter = await _pixelAt(legacy, 20, 20);
    final newCenter = await _pixelAt(migrated, 20, 20);
    for (var index = 0; index < 3; index++) {
      expect((oldCenter[index] - newCenter[index]).abs(), lessThan(8));
    }
  });

  test('a retained source only recovers its own uploaded avatar', () async {
    final bytes = await _twoColorSource();
    final source = ProfileImageSource(
      bytes: bytes,
      transform: const ProfileImageTransform(scale: 2, offset: Offset(.2, 0)),
    );
    final uploaded = await renderProfileImage(
      bytes,
      transform: source.transform,
    );
    final other = await renderProfileImage(
      bytes,
      transform: const ProfileImageTransform(flipHorizontal: true),
    );
    expect(await sourceMatchesAvatar(source, uploaded), isTrue);
    expect(await sourceMatchesAvatar(source, other), isFalse);

    final legacy = ProfileImageSource(
      bytes: bytes,
      legacyZoom: 2,
      legacyHorizontal: 1,
    );
    final legacyUpload = await cropProfileImage(
      bytes,
      zoom: 2,
      horizontal: 1,
      vertical: 0,
    );
    expect(await sourceMatchesAvatar(legacy, legacyUpload), isTrue);
  });
}

Future<Uint8List> _twoColorSource() async {
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
  final sourceData = await image.toByteData(format: ui.ImageByteFormat.png);
  final source = sourceData!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return source;
}

Future<List<int>> _centerPixel(Uint8List bytes) async {
  return _pixelAt(bytes, 10, 10);
}

Future<List<int>> _pixelAt(Uint8List bytes, int x, int y) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    return data!.buffer.asUint8List().sublist(offset, offset + 4);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

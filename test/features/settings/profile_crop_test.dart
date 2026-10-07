import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/settings/application/profile_crop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reframing one rectangular source changes the square upload', () async {
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
}

Future<List<int>> _centerPixel(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    expect(image.width, 20);
    expect(image.height, 20);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (10 * 20 + 10) * 4;
    return data!.buffer.asUint8List().sublist(offset, offset + 4);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

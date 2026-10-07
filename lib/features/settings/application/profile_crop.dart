import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Large selections are scaled as a whole before local storage. No edges are
/// discarded; the separate square crop is made only for the Matrix upload.
Future<Uint8List> prepareProfileSource(Uint8List bytes) async {
  if (bytes.lengthInBytes <= 30 * 1024 * 1024) return bytes;
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    final scale =
        2048 / (image.width > image.height ? image.width : image.height);
    final width = (image.width * scale).round().clamp(1, image.width);
    final height = (image.height * scale).round().clamp(1, image.height);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    try {
      final resized = await picture.toImage(width, height);
      try {
        final data = await resized.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Could not prepare profile picture.');
        }
        return data.buffer.asUint8List();
      } finally {
        resized.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// Makes a square upload from the retained, uncropped source image.
Future<Uint8List> cropProfileImage(
  Uint8List source, {
  required double zoom,
  required double horizontal,
  required double vertical,
  int outputSize = 512,
}) async {
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final side =
        (image.width < image.height ? image.width : image.height) /
        zoom.clamp(1.0, 4.0);
    final left = (image.width - side) * ((horizontal.clamp(-1.0, 1.0) + 1) / 2);
    final top = (image.height - side) * ((vertical.clamp(-1.0, 1.0) + 1) / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(left, top, side, side),
      Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    try {
      final output = await picture.toImage(outputSize, outputSize);
      try {
        final data = await output.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Could not encode profile picture.');
        return data.buffer.asUint8List();
      } finally {
        output.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}

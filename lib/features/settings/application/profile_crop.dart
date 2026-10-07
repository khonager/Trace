import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Large selections are scaled as a whole before local storage. No edges are
/// discarded; a separate square render is made only for the Matrix upload.
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
    return await cropProfileImageFromDecoded(
      image,
      zoom: zoom,
      horizontal: horizontal,
      vertical: vertical,
      outputSize: outputSize,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

Rect profileCropRect(
  Size imageSize, {
  required double zoom,
  required double horizontal,
  required double vertical,
}) {
  final side =
      (imageSize.width < imageSize.height
          ? imageSize.width
          : imageSize.height) /
      zoom.clamp(1.0, 4.0);
  final left =
      (imageSize.width - side) * ((horizontal.clamp(-1.0, 1.0) + 1) / 2);
  final top = (imageSize.height - side) * ((vertical.clamp(-1.0, 1.0) + 1) / 2);
  return Rect.fromLTWH(left, top, side, side);
}

/// Renders from an already decoded image so saving does not decode it again.
Future<Uint8List> cropProfileImageFromDecoded(
  ui.Image image, {
  required double zoom,
  required double horizontal,
  required double vertical,
  int outputSize = 512,
}) async {
  final sourceRect = profileCropRect(
    Size(image.width.toDouble(), image.height.toDouble()),
    zoom: zoom,
    horizontal: horizontal,
    vertical: vertical,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    sourceRect,
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
}

/// Position is measured in fractions of the avatar square so it survives a
/// change in preview size. Scale 1 covers the square before rotation.
class ProfileImageTransform {
  const ProfileImageTransform({
    this.scale = 1,
    this.offset = Offset.zero,
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final double scale;
  final Offset offset;
  final double rotation;
  final bool flipHorizontal;
  final bool flipVertical;

  ProfileImageTransform copyWith({
    double? scale,
    Offset? offset,
    double? rotation,
    bool? flipHorizontal,
    bool? flipVertical,
  }) => ProfileImageTransform(
    scale: scale ?? this.scale,
    offset: offset ?? this.offset,
    rotation: rotation ?? this.rotation,
    flipHorizontal: flipHorizontal ?? this.flipHorizontal,
    flipVertical: flipVertical ?? this.flipVertical,
  );

  static ProfileImageTransform fromLegacy(
    Size imageSize, {
    required double zoom,
    required double horizontal,
    required double vertical,
  }) {
    final shortest = math.min(imageSize.width, imageSize.height);
    final actualZoom = zoom.clamp(1.0, 4.0);
    final side = shortest / actualZoom;
    final cropCenterX =
        (imageSize.width - side) * (horizontal.clamp(-1.0, 1.0) + 1) / 2 +
        side / 2;
    final cropCenterY =
        (imageSize.height - side) * (vertical.clamp(-1.0, 1.0) + 1) / 2 +
        side / 2;
    return ProfileImageTransform(
      scale: actualZoom,
      offset: Offset(
        (imageSize.width / 2 - cropCenterX) * actualZoom / shortest,
        (imageSize.height / 2 - cropCenterY) * actualZoom / shortest,
      ),
    );
  }
}

/// Keeps the point under the fingers anchored during drag, pinch, and rotate.
ProfileImageTransform transformProfileGesture({
  required ProfileImageTransform start,
  required Offset startFocalPoint,
  required Offset focalPoint,
  required double gestureScale,
  required double gestureRotation,
  required double viewportSize,
}) {
  final nextScale = (start.scale * gestureScale).clamp(0.25, 6.0);
  final ratio = nextScale / start.scale;
  final center = Offset(viewportSize / 2, viewportSize / 2);
  final startCenter = center + start.offset * viewportSize;
  final anchored = startFocalPoint - startCenter;
  final cosine = math.cos(gestureRotation);
  final sine = math.sin(gestureRotation);
  final moved = Offset(
    (anchored.dx * cosine - anchored.dy * sine) * ratio,
    (anchored.dx * sine + anchored.dy * cosine) * ratio,
  );
  final nextCenter = focalPoint - moved;
  return start.copyWith(
    scale: nextScale,
    offset: Offset(
      ((nextCenter.dx - center.dx) / viewportSize).clamp(-1.5, 1.5),
      ((nextCenter.dy - center.dy) / viewportSize).clamp(-1.5, 1.5),
    ),
    rotation: math.atan2(
      math.sin(start.rotation + gestureRotation),
      math.cos(start.rotation + gestureRotation),
    ),
  );
}

/// The editor preview and exported PNG share this exact drawing path.
void paintProfileImage(
  Canvas canvas,
  Size size,
  ui.Image image,
  ProfileImageTransform transform,
) {
  final bounds = Offset.zero & size;
  final center = bounds.center;
  final cover = math.max(size.width / image.width, size.height / image.height);
  canvas.save();
  canvas.clipRect(bounds);
  canvas.drawColor(const Color(0xFF202124), BlendMode.srcOver);
  canvas.saveLayer(
    bounds,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: size.width * .06,
        sigmaY: size.height * .06,
        tileMode: ui.TileMode.clamp,
      ),
  );
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(cover * 1.3);
  canvas.drawImage(
    image,
    Offset(-image.width / 2, -image.height / 2),
    Paint()..filterQuality = FilterQuality.low,
  );
  canvas.restore();
  canvas.restore();

  canvas.save();
  canvas.translate(
    center.dx + transform.offset.dx * size.width,
    center.dy + transform.offset.dy * size.height,
  );
  canvas.rotate(transform.rotation);
  canvas.scale(
    cover * transform.scale * (transform.flipHorizontal ? -1 : 1),
    cover * transform.scale * (transform.flipVertical ? -1 : 1),
  );
  canvas.drawImage(
    image,
    Offset(-image.width / 2, -image.height / 2),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
  canvas.restore();
}

Future<Uint8List> renderProfileImage(
  Uint8List source, {
  required ProfileImageTransform transform,
  int outputSize = 512,
}) async {
  final codec = await ui.instantiateImageCodec(source);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  try {
    return await renderProfileImageFromDecoded(
      image,
      transform: transform,
      outputSize: outputSize,
    );
  } finally {
    image.dispose();
  }
}

Future<Uint8List> renderProfileImageFromDecoded(
  ui.Image image, {
  required ProfileImageTransform transform,
  int outputSize = 512,
}) async {
  final recorder = ui.PictureRecorder();
  paintProfileImage(
    Canvas(recorder),
    Size.square(outputSize.toDouble()),
    image,
    transform,
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
}

class ProfileImagePainter extends CustomPainter {
  const ProfileImagePainter({required this.image, required this.transform});

  final ui.Image image;
  final ProfileImageTransform transform;

  @override
  void paint(Canvas canvas, Size size) =>
      paintProfileImage(canvas, size, image, transform);

  @override
  bool shouldRepaint(ProfileImagePainter oldDelegate) =>
      image != oldDelegate.image ||
      transform.scale != oldDelegate.transform.scale ||
      transform.offset != oldDelegate.transform.offset ||
      transform.rotation != oldDelegate.transform.rotation ||
      transform.flipHorizontal != oldDelegate.transform.flipHorizontal ||
      transform.flipVertical != oldDelegate.transform.flipVertical;
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/application/profile_image_store.dart';
import 'package:flutter/widgets.dart';

Future<Directory> _sourceDirectory() async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/profile_sources');
  await directory.create(recursive: true);
  return directory;
}

Future<File> _sourceFile(String key) async {
  final safeKey = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  return File('${(await _sourceDirectory()).path}/$safeKey.image');
}

Future<File> _uriFile(String key) async =>
    File('${(await _sourceFile(key)).path}.uri');

Future<ProfileImageSource?> readProfileSource(
  String key,
  Uri? avatarUri,
) async {
  try {
    final image = await _sourceFile(key);
    final marker = await _uriFile(key);
    if (!await image.exists() || !await marker.exists()) return null;
    final metadata = jsonDecode(await marker.readAsString());
    if (metadata is! Map<String, dynamic> ||
        metadata['uri'] != (avatarUri?.toString() ?? '')) {
      return null;
    }
    final bytes = await image.readAsBytes();
    if (metadata['version'] == 2) {
      return ProfileImageSource(
        bytes: bytes,
        transform: ProfileImageTransform(
          scale: ((metadata['scale'] as num?)?.toDouble() ?? 1).clamp(.25, 6),
          offset: Offset(
            ((metadata['offsetX'] as num?)?.toDouble() ?? 0).clamp(-1.5, 1.5),
            ((metadata['offsetY'] as num?)?.toDouble() ?? 0).clamp(-1.5, 1.5),
          ),
          rotation: (metadata['rotation'] as num?)?.toDouble() ?? 0,
          flipHorizontal: metadata['flipHorizontal'] == true,
          flipVertical: metadata['flipVertical'] == true,
        ),
      );
    }
    return ProfileImageSource(
      bytes: bytes,
      legacyZoom: ((metadata['zoom'] as num?)?.toDouble() ?? 1).clamp(1.0, 4.0),
      legacyHorizontal: ((metadata['horizontal'] as num?)?.toDouble() ?? 0)
          .clamp(-1.0, 1.0),
      legacyVertical: ((metadata['vertical'] as num?)?.toDouble() ?? 0).clamp(
        -1.0,
        1.0,
      ),
    );
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

Future<void> writeProfileSource(
  String key,
  Uri? avatarUri,
  ProfileImageSource source,
) async {
  final image = await _sourceFile(key);
  final pending = File('${image.path}.pending');
  await pending.writeAsBytes(source.bytes, flush: true);
  await pending.rename(image.path);
  await (await _uriFile(key)).writeAsString(
    jsonEncode({
      'version': 2,
      'uri': avatarUri?.toString() ?? '',
      'scale': source.transform.scale,
      'offsetX': source.transform.offset.dx,
      'offsetY': source.transform.offset.dy,
      'rotation': source.transform.rotation,
      'flipHorizontal': source.transform.flipHorizontal,
      'flipVertical': source.transform.flipVertical,
    }),
    flush: true,
  );
}

Future<void> deleteProfileSource(String key) async {
  for (final file in [await _sourceFile(key), await _uriFile(key)]) {
    if (await file.exists()) await file.delete();
  }
}

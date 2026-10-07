import 'dart:typed_data';

import 'package:trace/features/settings/application/profile_image_store.dart';

Future<ProfileImageSource?> readProfileSource(
  String key,
  Uri? avatarUri,
) async => null;
Future<ProfileImageSource?> recoverProfileSource(
  String key,
  Uri avatarUri,
  Uint8List avatarBytes,
) async => null;
Future<void> writeProfileSource(
  String key,
  Uri? avatarUri,
  ProfileImageSource source,
) async {}
Future<void> deleteProfileSource(String key) async {}

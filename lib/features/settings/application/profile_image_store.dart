import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:trace/features/settings/application/profile_crop.dart';

import 'package:trace/features/settings/infrastructure/profile_image_store_stub.dart'
    if (dart.library.io) 'package:trace/features/settings/infrastructure/profile_image_store_io.dart'
    as platform;

/// The source is kept at its full aspect ratio, separate from the square
/// picture uploaded to Matrix. The avatar URI guards against stale sources
/// when another client changes the profile picture.
class ProfileImageStore {
  const ProfileImageStore();

  Future<ProfileImageSource?> read(String accountKey, Uri? avatarUri) =>
      platform.readProfileSource(accountKey, avatarUri);

  Future<void> write(
    String accountKey,
    Uri? avatarUri,
    ProfileImageSource source,
  ) => platform.writeProfileSource(accountKey, avatarUri, source);

  Future<void> delete(String accountKey) =>
      platform.deleteProfileSource(accountKey);
}

class ProfileImageSource {
  const ProfileImageSource({
    required this.bytes,
    this.transform = const ProfileImageTransform(),
    this.legacyZoom,
    this.legacyHorizontal = 0,
    this.legacyVertical = 0,
  });

  final Uint8List bytes;
  final ProfileImageTransform transform;
  final double? legacyZoom;
  final double legacyHorizontal;
  final double legacyVertical;

  ProfileImageTransform transformFor(Size imageSize) => legacyZoom == null
      ? transform
      : ProfileImageTransform.fromLegacy(
          imageSize,
          zoom: legacyZoom!,
          horizontal: legacyHorizontal,
          vertical: legacyVertical,
        );
}

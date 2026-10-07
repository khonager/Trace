import 'dart:typed_data';

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
    this.zoom = 1,
    this.horizontal = 0,
    this.vertical = 0,
  });

  final Uint8List bytes;
  final double zoom;
  final double horizontal;
  final double vertical;
}

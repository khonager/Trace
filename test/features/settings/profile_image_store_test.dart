import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/application/profile_image_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recovers a retained source only when it matches the current avatar',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'trace-profile-store-',
      );
      final originalProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPathProvider(root.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalProvider;
        await root.delete(recursive: true);
      });

      final sourceBytes = File('assets/profiles/maya.webp').readAsBytesSync();
      final source = ProfileImageSource(
        bytes: sourceBytes,
        transform: const ProfileImageTransform(scale: 2),
      );
      final store = ProfileImageStore();
      final oldUri = Uri.parse('mxc://example.org/old');
      final newUri = Uri.parse('mxc://example.org/new');
      await store.write('account', oldUri, source);
      expect(await store.read('account', newUri), isNull);

      final otherAvatar = await renderProfileImage(
        sourceBytes,
        transform: const ProfileImageTransform(flipHorizontal: true),
      );
      expect(await store.recover('account', newUri, otherAvatar), isNull);
      expect(await store.read('account', newUri), isNull);

      final uploaded = await renderProfileImage(
        sourceBytes,
        transform: source.transform,
      );
      final recovered = await store.recover('account', newUri, uploaded);
      expect(listEquals(recovered?.bytes, sourceBytes), isTrue);
      expect((await store.read('account', newUri))?.transform.scale, 2);
      expect(await store.read('account', oldUri), isNull);
    },
  );
}

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

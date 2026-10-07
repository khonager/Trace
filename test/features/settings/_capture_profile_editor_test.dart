import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/presentation/profile_picture_editor.dart';

void main() {
  testWidgets('capture profile editor', (tester) async {
    const mode = String.fromEnvironment(
      'PROFILE_PREVIEW',
      defaultValue: 'narrow',
    );
    await tester.binding.setSurfaceSize(
      mode == 'wide' ? const Size(900, 700) : const Size(360, 760),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const Key('capture'),
          child: ProfilePictureEditor(
            source: File('assets/profiles/maya.webp').readAsBytesSync(),
            initialTransform: const ProfileImageTransform(scale: .65),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    if (mode == 'square') {
      await tester.tap(find.byKey(const Key('profile-preview-shape-toggle')));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile(
        '../../../docs/product/profile-picture-editor-$mode.png',
      ),
    );
  });
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/hidden_chats.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';

void main() {
  testWidgets(
    'capture hidden group controls on a phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locks = LockController(
        read: () async =>
            '{"group:Work":{"method":"device","rooms":["work"]},"group:Private":{"method":"device","rooms":["private"]}}',
        authenticateDevice: (_) async => true,
      );
      await locks.load();
      await locks.verify('group:Work');
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            builder: (_, child) => LockScope(controller: locks, child: child!),
            home: const Scaffold(
              body: SafeArea(child: HiddenChatsTile(client: null)),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hidden chats'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/hidden-chats.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
    skip: !const bool.fromEnvironment('TRACE_CAPTURE'),
  );
}

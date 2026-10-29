import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/hidden_chats.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
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
      final fontPath = Platform.environment['TRACE_PREVIEW_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('Preview');
        loader.addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
        await loader.load();
      }
      final locks = LockController(
        read: () async =>
            '{"group:Work":{"method":"device","rooms":["work"]},"group:Private":{"method":"device","rooms":["private"]}}',
        authenticateDevice: (_) async => true,
      );
      addTearDown(locks.dispose);
      await locks.load();
      await locks.verify('group:Work');
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF202124),
                surface: Color(0xFFF7F7F5),
              ),
              fontFamily: fontPath == null ? null : 'Preview',
              splashFactory: InkRipple.splashFactory,
            ),
            builder: (_, child) => LockScope(controller: locks, child: child!),
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showSpaceManager(
                      context,
                      locks,
                      _PreviewClient(),
                      'group:Work',
                    ),
                    child: const Text('Settings'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
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
      locks.hideGroups();
      await tester.pump();
    },
    skip: !const bool.fromEnvironment('TRACE_CAPTURE'),
  );
}

class _PreviewClient implements MatrixClientPort {
  @override
  MatrixClientSnapshot get current => MatrixClientSnapshot(
    phase: MatrixConnectionPhase.ready,
    rooms: [
      for (final entry in {
        'work': 'Sprint planning',
        'team': 'Team standup',
      }.entries)
        MatrixRoom(
          id: entry.key,
          name: entry.value,
          preview: '',
          timestamp: DateTime(2026),
          membership: MatrixRoomMembership.joined,
          unreadCount: 0,
          encrypted: true,
          isDirect: false,
        ),
    ],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

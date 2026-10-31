import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/presentation/voice_message_dialog.dart';
import 'voice_message_dialog_test.dart' show FakeRecorder;

void main() {
  testWidgets(
    'capture voice recording controls',
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
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: fontPath == null ? null : 'Preview',
              splashFactory: InkRipple.splashFactory,
            ),
            home: Scaffold(
              body: VoiceMessageDialog(
                recorder: FakeRecorder(),
                send: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Record'));
      await tester.pump(const Duration(seconds: 12));
      await tester.tap(find.text('Stop recording'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/voice-message.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
    skip: !const bool.fromEnvironment('TRACE_CAPTURE'),
  );
}

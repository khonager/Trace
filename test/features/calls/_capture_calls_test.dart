import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/calls/application/call_service.dart';
import 'package:trace/features/calls/presentation/calls_page.dart';
import 'calls_page_test.dart' show FakeCalls, FakeCallClient, callRoom;

void main() {
  testWidgets(
    'capture foreground call controls',
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
      final iconPath = Platform.environment['TRACE_ICON_FONT'];
      if (iconPath != null) {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(
          Future.value(ByteData.sublistView(File(iconPath).readAsBytesSync())),
        );
        await loader.load();
      }
      final calls = FakeCalls()
        ..current = const TraceCall(
          roomId: 'Alex',
          phase: CallPhase.ringing,
          incoming: true,
        );
      final client = FakeCallClient([callRoom('Alex'), callRoom('Sam')]);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: fontPath == null ? null : 'Preview',
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF202124),
                surface: Color(0xFFF7F7F5),
              ),
              splashFactory: InkRipple.splashFactory,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    CallControls(calls: calls, client: client),
                    Expanded(
                      child: CallsPage(calls: calls, client: client),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/voice-call.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
    skip: !const bool.fromEnvironment('TRACE_CAPTURE'),
  );
}

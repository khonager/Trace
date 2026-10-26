import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/trace_app.dart';

void main() {
  testWidgets('capture chat navigation', (tester) async {
    final fontPath = Platform.environment['TRACE_PREVIEW_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    const mode = String.fromEnvironment('CHAT_PREVIEW', defaultValue: 'wide');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = mode == 'narrow'
        ? const Size(390, 800)
        : const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const RepaintBoundary(key: Key('capture'), child: TraceApp()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    if (mode == 'expanded') {
      await tester.tap(find.byKey(const Key('desktop-chat-list-toggle')));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('../../docs/product/chat-navigation-$mode.png'),
    );
  }, skip: Platform.environment['TRACE_PREVIEW_FONT'] == null);
}

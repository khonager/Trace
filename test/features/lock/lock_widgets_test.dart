import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';

void main() {
  testWidgets(
    'protected chat previews and messages stay hidden in overview and search',
    (tester) async {
      final locks = LockController(
        read: () async => '{"maya":{"method":"device"}}',
      );
      await locks.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => LockScope(controller: locks, child: child!),
          home: const Scaffold(body: ChatsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('That works for me. See you then.'), findsNothing);
      expect(find.text('Are we still on for the call later?'), findsNothing);
      await tester.tap(find.byTooltip('Search').first);
      await tester.pumpAndSettle();
      expect(find.text('That works for me. See you then.'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('chat-search-field')),
        'notes before',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Maya'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('lock screen fits a narrow device', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const fontDir = String.fromEnvironment('LOCK_FONT_DIR');
    if (fontDir.isNotEmpty) {
      await tester.runAsync(() async {
        for (final entry in {
          'Roboto': 'Roboto-Regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key);
          loader.addFont(
            File(
              '$fontDir/${entry.value}',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
          await loader.load();
        }
      });
    }
    final locks = LockController(
      read: () async => '{"app":{"method":"device"}}',
    );
    await locks.load();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: fontDir.isEmpty ? null : "Roboto"),
          home: Scaffold(
            body: LockPrompt(locks: locks, id: 'app'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    const path = String.fromEnvironment('LOCK_SCREENSHOT');
    if (path.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('app lock covers navigator routes and relocks on background', (
    tester,
  ) async {
    final locks = LockController(
      read: () async => '{"app":{"method":"device"}}',
      authenticateDevice: (_) async => true,
    );
    await locks.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => LockHost(controller: locks, child: child!),
        home: const Scaffold(body: Text('Private messages')),
      ),
    );
    expect(find.text('Private messages'), findsNothing);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Private messages'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Private messages'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Trace is locked'), findsOneWidget);
    expect(find.text('Private messages'), findsNothing);
  });

  testWidgets('chat guard hides content until that chat authenticates', (
    tester,
  ) async {
    final locks = LockController(
      read: () async => '{"room":{"method":"device"}}',
      authenticateDevice: (_) async => true,
    );
    await locks.load();
    await tester.pumpWidget(
      MaterialApp(
        home: LockScope(
          controller: locks,
          child: const Scaffold(
            body: ChatLockGuard(id: 'room', child: Text('Secret chat')),
          ),
        ),
      ),
    );
    expect(find.text('Secret chat'), findsNothing);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Secret chat'), findsOneWidget);
    locks.lockAll();
    await tester.pump();
    expect(find.text('Secret chat'), findsNothing);
  });
}

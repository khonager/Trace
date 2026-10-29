import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';
import 'package:trace/features/lock/privacy_routes.dart';
import 'package:trace/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets(
    'ordinary settings do not advertise spaces or reveal their names',
    (tester) async {
      final locks = LockController(
        read: () async =>
            '{"group:Private":{"method":"device","rooms":["secret"]}}',
      );
      addTearDown(locks.dispose);
      await locks.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => LockScope(controller: locks, child: child!),
          home: const Scaffold(body: SettingsPage()),
        ),
      );
      expect(find.text('Hidden chats'), findsNothing);
      expect(find.text('Private'), findsNothing);
      await tester.longPress(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Access'), findsOneWidget);
      expect(find.text('Private'), findsNothing);
      expect(find.text('group:Private'), findsNothing);
    },
  );

  for (final background in [false, true]) {
    testWidgets(
      'space closes ${background ? 'on background' : 'on inactivity'} without an unlock prompt',
      (tester) async {
        final locks = LockController(
          spaceIdleTimeout: const Duration(seconds: 2),
          read: () async =>
              '{"group:Private":{"method":"device","rooms":["secret"]}}',
          authenticateDevice: (_) async => true,
        );
        addTearDown(locks.dispose);
        await locks.load();
        final routes = PrivacyRoutes();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [routes],
            builder: (_, child) => LockHost(
              controller: locks,
              onSpacesClosed: routes.closeTransientRoutes,
              child: child!,
            ),
            home: Scaffold(
              body: ListenableBuilder(
                listenable: locks,
                builder: (_, _) => Text(
                  locks.hidden('secret') ? 'Ordinary chats' : 'Secret chat',
                ),
              ),
            ),
          ),
        );
        expect(locks.enabled(LockController.app), isFalse);
        await locks.verify('group:Private');
        await tester.pump();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Private attachment')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Private attachment'), findsOneWidget);
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        } else {
          await tester.pump(const Duration(seconds: 3));
        }
        await tester.pumpAndSettle();
        expect(locks.hidden('secret'), isTrue);
        expect(locks.resumeLock, isNull);
        expect(find.text('Private attachment'), findsNothing);
        expect(find.text('Secret chat'), findsNothing);
        expect(find.text('Ordinary chats'), findsOneWidget);
        expect(find.text('Unlock Private chats'), findsNothing);
      },
    );
  }
}

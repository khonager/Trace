import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';

void main() {
  testWidgets('deleting or clearing a passcode stays empty after rebuilds', (
    tester,
  ) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    Widget app() => MaterialApp(
      home: Scaffold(
        body: SecretInput(method: LockMethod.passcode, controller: input),
      ),
    );
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField), '123456');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '12345',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    expect(input.text, '12345');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
    );
    await tester.pumpWidget(app());
    expect(input.text, isEmpty);
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear credential'));
    await tester.pumpWidget(app());
    expect(input.text, isEmpty);
    expect(input.value.composing, TextRange.empty);
    expect(tester.testTextInput.editingState?['text'], '');
    await tester.enterText(find.byType(TextField), '123456');
    expect(input.text, '123456');
  });

  testWidgets(
    'a failed unlock clears the credential and allows another attempt',
    (tester) async {
      final locks = LockController(read: () async => null, write: (_) async {});
      await locks.load();
      await tester.runAsync(
        () => locks.configure('room', LockMethod.passcode, secret: '123456'),
      );
      addTearDown(locks.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockPrompt(locks: locks, id: 'room'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '654321');
      // Password hashing runs outside the widget test's fake clock.
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Unlock'))
            .onPressed!();
        while (locks.authenticating) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(locks.locked('room'), isTrue);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Unlock'))
            .onPressed!();
        while (locks.authenticating) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(locks.locked('room'), isFalse);
    },
  );
}

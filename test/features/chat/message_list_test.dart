import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/presentation/message_list.dart';

void main() {
  testWidgets('typing and older history preserve the visible message', (
    tester,
  ) async {
    final ids = List<Object>.generate(60, (index) => index);
    var typing = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MessageList(
                messageIds: List.of(ids),
                typingIndicator: typing ? const SizedBox(height: 45) : null,
                onLoadOlder: () async {},
                itemBuilder: (context, index) =>
                    SizedBox(height: 70, child: Text('Message ${ids[index]}')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    final anchor = find.text('Message 12');
    final before = tester.getTopLeft(anchor);
    update(() => typing = true);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(anchor), before);
    update(() {
      typing = false;
      ids.addAll(List.generate(40, (index) => index + 60));
    });
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(anchor), before);
  });

  testWidgets('follows new messages only at the live edge', (tester) async {
    final ids = List<Object>.generate(60, (index) => index);
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MessageList(
                messageIds: List.of(ids),
                onLoadOlder: () async {},
                itemBuilder: (context, index) =>
                    SizedBox(height: 70, child: Text('Message ${ids[index]}')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bottom = tester.getTopLeft(find.text('Message 0'));
    update(() => ids.insert(0, 'new'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Message new')), bottom);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    final anchor = find.text('Message 12');
    final before = tester.getTopLeft(anchor);
    update(() => ids.insert(0, 'another'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(anchor), before);
  });

  testWidgets('coalesces overlapping history requests', (tester) async {
    final pending = Completer<void>();
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageList(
            messageIds: List.generate(15, (index) => index),
            onLoadOlder: () {
              requests++;
              return pending.future;
            },
            itemBuilder: (context, index) => const SizedBox(height: 70),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(requests, 1);
    pending.complete();
    await tester.pump();
  });
}

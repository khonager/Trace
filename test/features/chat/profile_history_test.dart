import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/chat/application/profile_history.dart';

void main() {
  test(
    'opt-in history persists changes and respects individual and bulk deletion',
    () async {
      String? saved;
      final store = ProfileHistoryStore(
        account: 'test',
        loadThumbnail: (_) async => Uint8List.fromList([1, 2, 3]),
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
      );
      await store.ready;
      await store.observe('alice', 'Alice', Uri.parse('mxc://server/one'));
      expect(store.entries('alice'), isEmpty);
      await store.setEnabled('alice', true);
      await store.observe('alice', 'Alice', Uri.parse('mxc://server/one'));
      await store.observe('alice', 'Alice', Uri.parse('mxc://server/one'));
      await store.observe('alice', 'New Alice', Uri.parse('mxc://server/two'));
      expect(store.entries('alice'), hasLength(2));
      final restored = ProfileHistoryStore(
        account: 'test',
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
      );
      await restored.ready;
      expect(restored.entries('alice').first.name, 'New Alice');
      expect(restored.entries('alice').first.thumbnail, [1, 2, 3]);
      await restored.delete('alice', restored.entries('alice').first);
      await restored.observe(
        'alice',
        'New Alice',
        Uri.parse('mxc://server/two'),
      );
      expect(restored.entries('alice'), hasLength(1));
      await restored.clear('alice');
      await restored.observe(
        'alice',
        'New Alice',
        Uri.parse('mxc://server/two'),
      );
      expect(restored.entries('alice'), isEmpty);
      await restored.setEnabled('alice', false);
      await restored.observe('alice', 'Third Alice', null);
      expect(restored.entries('alice'), isEmpty);
      store.dispose();
      restored.dispose();
    },
  );

  test('failed writes restore the previous state', () async {
    final store = ProfileHistoryStore(
      account: 'test',
      read: () async => null,
      write: (_) async => throw StateError('unavailable'),
    );
    await store.ready;
    await expectLater(store.setEnabled('alice', true), throwsStateError);
    expect(store.enabled('alice'), isFalse);
    store.dispose();
  });
}

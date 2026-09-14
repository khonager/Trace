import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/features/chat/application/media_favorites.dart';
import 'package:trace/features/chat/application/media_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists GIF and sticker favorites separately', () async {
    final store = SharedPreferencesMediaFavoriteStore();
    final gif = _result(id: 'gif-one', source: 'Brave');
    final sticker = _result(id: 'sticker-one', source: 'GIPHY');

    await store.save(MediaSearchKind.gif, [gif]);
    await store.save(MediaSearchKind.sticker, [sticker]);

    final gifs = await store.load(MediaSearchKind.gif);
    final stickers = await store.load(MediaSearchKind.sticker);
    expect(gifs.single.id, 'gif-one');
    expect(gifs.single.source, 'Brave');
    expect(stickers.single.id, 'sticker-one');
    expect(stickers.single.source, 'GIPHY');
  });

  test('ignores malformed stored favorites', () async {
    SharedPreferences.setMockInitialValues({
      'chat.media_favorites.v1.gif': ['not json', '{}'],
    });

    final favorites = await SharedPreferencesMediaFavoriteStore().load(
      MediaSearchKind.gif,
    );

    expect(favorites, isEmpty);
  });
}

MediaSearchResult _result({required String id, required String source}) =>
    MediaSearchResult(
      id: id,
      title: 'Favorite media',
      previewUri: Uri.parse('https://media.example/$id-preview.gif'),
      downloadUri: Uri.parse('https://media.example/$id.gif'),
      mimeType: 'image/gif',
      source: source,
      width: 200,
      height: 160,
    );

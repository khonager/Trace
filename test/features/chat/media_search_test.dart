import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trace/features/chat/application/configured_media_search_client.dart';
import 'package:trace/features/chat/application/media_search.dart';
import 'package:trace/features/chat/application/relay_media_search_client.dart';

void main() {
  test(
    'relay search sends safety and media kind and decodes results',
    () async {
      late Uri requestedUri;
      final client = RelayMediaSearchClient(
        endpoint: Uri.parse('https://relay.example/base'),
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 'one',
                  'title': 'Hello',
                  'previewUrl': 'https://relay.example/preview',
                  'downloadUrl': 'https://relay.example/download',
                  'mimeType': 'image/gif',
                  'source': 'Brave',
                  'width': 320,
                  'height': 180,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final results = await client.search(
        query: 'hello there',
        kind: MediaSearchKind.gif,
        safety: MediaSearchSafety.open,
      );

      expect(requestedUri.path, '/base/v1/media/search');
      expect(requestedUri.queryParameters['q'], 'hello there');
      expect(requestedUri.queryParameters['kind'], 'gif');
      expect(requestedUri.queryParameters['safety'], 'open');
      expect(results.single.source, 'Brave');
      expect(results.single.width, 320);
    },
  );

  test('GIPHY open search omits a restrictive rating', () async {
    late Uri requestedUri;
    final giphy = GiphyMediaSearchClient(
      apiKey: 'app-key',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'sticker-one',
                'title': 'Sticker one',
                'images': {
                  'fixed_width': {'url': 'https://media.giphy.com/preview.gif'},
                  'original': {
                    'url': 'https://media.giphy.com/original.gif',
                    'width': '200',
                    'height': '160',
                  },
                },
              },
              {
                'id': 'sticker-two',
                'title': 'Sticker two',
                'images': {
                  'fixed_width': {
                    'url': 'https://media.giphy.com/preview-two.gif',
                  },
                  'original': {
                    'url': 'https://media.giphy.com/original-two.gif',
                    'width': '180',
                    'height': '180',
                  },
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    final client = ConfiguredMediaSearchClient(
      relay: RelayMediaSearchClient(endpoint: Uri()),
      giphy: giphy,
    );

    final results = await client.search(
      query: 'party',
      kind: MediaSearchKind.sticker,
      safety: MediaSearchSafety.open,
    );

    expect(requestedUri.path, '/v1/stickers/search');
    expect(requestedUri.queryParameters['api_key'], 'app-key');
    expect(requestedUri.queryParameters['limit'], '50');
    expect(requestedUri.queryParameters.containsKey('rating'), isFalse);
    expect(results.map((result) => result.id), ['sticker-one', 'sticker-two']);
    expect(results.first.source, 'GIPHY');
    expect(results.first.mimeType, 'image/gif');
  });

  test('GIPHY download rejects content that is not a GIF', () async {
    final client = GiphyMediaSearchClient(
      apiKey: 'app-key',
      httpClient: MockClient(
        (_) async => http.Response(
          '<html>not media</html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    final result = MediaSearchResult(
      id: 'bad',
      title: 'Bad',
      previewUri: Uri.parse('https://media.giphy.com/preview.gif'),
      downloadUri: Uri.parse('https://media.giphy.com/bad'),
      mimeType: 'image/gif',
      source: 'GIPHY',
    );

    await expectLater(
      client.download(result),
      throwsA(
        isA<MediaSearchException>().having(
          (error) => error.message,
          'message',
          contains('unsupported media type'),
        ),
      ),
    );
  });
}

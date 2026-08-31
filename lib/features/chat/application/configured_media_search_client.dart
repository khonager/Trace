import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:trace/features/chat/application/media_search.dart';
import 'package:trace/features/chat/application/relay_media_search_client.dart';

/// Combines Trace's open-web relay with GIPHY's direct client API.
///
/// Brave credentials remain on the relay. GIPHY requires client-side API
/// calls, so its integration key is supplied as a compile-time app setting.
final class ConfiguredMediaSearchClient implements MediaSearchPort {
  ConfiguredMediaSearchClient({
    RelayMediaSearchClient? relay,
    GiphyMediaSearchClient? giphy,
  }) : _providers = [
         relay ?? RelayMediaSearchClient(),
         giphy ?? GiphyMediaSearchClient(),
       ];

  final List<MediaSearchPort> _providers;

  Iterable<MediaSearchPort> get _configured =>
      _providers.where((provider) => provider.isConfigured);

  @override
  bool get isConfigured => _configured.isNotEmpty;

  @override
  Future<List<MediaSearchResult>> search({
    required String query,
    required MediaSearchKind kind,
    required MediaSearchSafety safety,
  }) async {
    final providers = _configured.toList(growable: false);
    if (providers.isEmpty) {
      throw const MediaSearchException('Media search is not configured.');
    }
    final results = <MediaSearchResult>[];
    Object? lastError;
    for (final provider in providers) {
      try {
        results.addAll(
          await provider.search(query: query, kind: kind, safety: safety),
        );
      } catch (error) {
        lastError = error;
      }
    }
    if (results.isEmpty && lastError != null) throw lastError;
    return results;
  }

  @override
  Future<DownloadedMedia> download(MediaSearchResult result) {
    final provider = result.source.toUpperCase() == 'GIPHY'
        ? _providers.whereType<GiphyMediaSearchClient>().firstOrNull
        : _providers.whereType<RelayMediaSearchClient>().firstOrNull;
    if (provider == null || !provider.isConfigured) {
      throw const MediaSearchException(
        'The provider for this result is unavailable.',
      );
    }
    return provider.download(result);
  }
}

final class GiphyMediaSearchClient implements MediaSearchPort {
  GiphyMediaSearchClient({String? apiKey, http.Client? httpClient})
    : _apiKey = apiKey ?? const String.fromEnvironment('TRACE_GIPHY_API_KEY'),
      _httpClient = httpClient ?? http.Client();

  static const _maximumDownloadBytes = 25 * 1024 * 1024;

  final String _apiKey;
  final http.Client _httpClient;

  @override
  bool get isConfigured => _apiKey.trim().isNotEmpty;

  @override
  Future<List<MediaSearchResult>> search({
    required String query,
    required MediaSearchKind kind,
    required MediaSearchSafety safety,
  }) async {
    if (!isConfigured) {
      throw const MediaSearchException('GIPHY search is not configured.');
    }
    final uri = Uri.https(
      'api.giphy.com',
      '/v1/${kind == MediaSearchKind.gif ? 'gifs' : 'stickers'}/search',
      {
        'api_key': _apiKey,
        'q': query.trim(),
        'limit': '50',
        if (safety == MediaSearchSafety.strict) 'rating': 'g',
      },
    );
    final response = await _httpClient
        .get(uri)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw const MediaSearchException(
            'GIPHY search took too long. Try again.',
          ),
        );
    if (response.statusCode != 200) {
      throw MediaSearchException(
        'GIPHY search failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const MediaSearchException('GIPHY returned an invalid response.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((item) => _decodeResult(Map<String, dynamic>.from(item)))
        .whereType<MediaSearchResult>()
        .toList(growable: false);
  }

  MediaSearchResult? _decodeResult(Map<String, dynamic> json) {
    final images = json['images'];
    if (images is! Map) return null;
    final preview = images['fixed_width'];
    final original = images['original'];
    if (preview is! Map || original is! Map) return null;
    final previewUri = Uri.tryParse(preview['url']?.toString() ?? '');
    final downloadUri = Uri.tryParse(original['url']?.toString() ?? '');
    if (previewUri == null || downloadUri == null) return null;
    return MediaSearchResult(
      id: json['id']?.toString() ?? downloadUri.toString(),
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'GIPHY media',
      previewUri: previewUri,
      downloadUri: downloadUri,
      mimeType: 'image/gif',
      source: 'GIPHY',
      width: int.tryParse(original['width']?.toString() ?? ''),
      height: int.tryParse(original['height']?.toString() ?? ''),
    );
  }

  @override
  Future<DownloadedMedia> download(MediaSearchResult result) async {
    final response = await _httpClient
        .get(result.downloadUri)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const MediaSearchException(
            'The selected GIPHY media took too long to download.',
          ),
        );
    if (response.statusCode != 200) {
      throw MediaSearchException(
        'GIPHY media download failed (${response.statusCode}).',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw const MediaSearchException('The selected media is empty.');
    }
    if (response.bodyBytes.length > _maximumDownloadBytes) {
      throw const MediaSearchException(
        'The selected media is larger than the 25 MB limit.',
      );
    }
    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType != 'image/gif') {
      throw MediaSearchException(
        'GIPHY returned an unsupported media type: ${contentType ?? 'unknown'}.',
      );
    }
    return DownloadedMedia(
      bytes: Uint8List.fromList(response.bodyBytes),
      mimeType: contentType!,
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:trace/features/chat/application/media_search.dart';

final class RelayMediaSearchClient implements MediaSearchPort {
  RelayMediaSearchClient({Uri? endpoint, http.Client? httpClient})
    : _endpoint = endpoint ?? _environmentEndpoint,
      _httpClient = httpClient ?? http.Client();

  static final Uri? _environmentEndpoint = Uri.tryParse(
    const String.fromEnvironment('TRACE_MEDIA_SEARCH_ENDPOINT'),
  );

  static const int _maximumDownloadBytes = 25 * 1024 * 1024;

  final Uri? _endpoint;
  final http.Client _httpClient;

  @override
  bool get isConfigured => _endpoint?.hasScheme == true;

  @override
  Future<List<MediaSearchResult>> search({
    required String query,
    required MediaSearchKind kind,
    required MediaSearchSafety safety,
  }) async {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const MediaSearchException('Media search is not configured.');
    }
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];
    final uri = endpoint.replace(
      path: '${endpoint.path.replaceFirst(RegExp(r'/$'), '')}/v1/media/search',
      queryParameters: {
        'q': normalizedQuery,
        'kind': kind.name,
        'safety': safety.name,
      },
    );
    final response = await _httpClient
        .get(uri)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw const MediaSearchException(
            'Media search took too long. Try again.',
          ),
        );
    if (response.statusCode != 200) {
      throw MediaSearchException(_responseError(response));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
      throw const MediaSearchException(
        'The media search service returned an invalid response.',
      );
    }
    return (decoded['results'] as List)
        .whereType<Map>()
        .map((value) => _decodeResult(Map<String, dynamic>.from(value)))
        .whereType<MediaSearchResult>()
        .toList(growable: false);
  }

  @override
  Future<DownloadedMedia> download(MediaSearchResult result) async {
    final response = await _httpClient
        .get(result.downloadUri)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const MediaSearchException(
            'The selected media took too long to download.',
          ),
        );
    if (response.statusCode != 200) {
      throw MediaSearchException(_responseError(response));
    }
    final length = response.contentLength ?? response.bodyBytes.length;
    if (length <= 0) {
      throw const MediaSearchException('The selected media is empty.');
    }
    if (length > _maximumDownloadBytes) {
      throw const MediaSearchException(
        'The selected media is larger than the 25 MB limit.',
      );
    }
    final mimeType =
        response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase() ??
        result.mimeType.toLowerCase();
    if (!_allowedMimeTypes.contains(mimeType)) {
      throw MediaSearchException('Unsupported media type: $mimeType.');
    }
    return DownloadedMedia(
      bytes: Uint8List.fromList(response.bodyBytes),
      mimeType: mimeType,
    );
  }

  static const _allowedMimeTypes = {
    'image/gif',
    'image/png',
    'image/webp',
    'video/mp4',
  };

  MediaSearchResult? _decodeResult(Map<String, dynamic> json) {
    final previewUri = Uri.tryParse(json['previewUrl']?.toString() ?? '');
    final downloadUri = Uri.tryParse(json['downloadUrl']?.toString() ?? '');
    if (previewUri == null || downloadUri == null) return null;
    final mimeType = json['mimeType']?.toString().toLowerCase() ?? '';
    if (!_allowedMimeTypes.contains(mimeType)) return null;
    return MediaSearchResult(
      id: json['id']?.toString() ?? downloadUri.toString(),
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'Untitled media',
      previewUri: previewUri,
      downloadUri: downloadUri,
      mimeType: mimeType,
      source: json['source']?.toString().trim().isNotEmpty == true
          ? json['source'].toString().trim()
          : 'Web',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  String _responseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Fall through to a stable error without exposing an upstream response.
    }
    return 'Media search failed (${response.statusCode}).';
  }
}

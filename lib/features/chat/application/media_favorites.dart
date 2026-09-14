import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/features/chat/application/media_search.dart';

abstract interface class MediaFavoriteStore {
  Future<List<MediaSearchResult>> load(MediaSearchKind kind);

  Future<void> save(MediaSearchKind kind, List<MediaSearchResult> favorites);
}

const int mediaFavoriteLimitPerKind = 100;

final class SharedPreferencesMediaFavoriteStore implements MediaFavoriteStore {
  static const _preferenceKeyPrefix = 'chat.media_favorites.v1';

  @override
  Future<List<MediaSearchResult>> load(MediaSearchKind kind) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded =
        preferences.getStringList('$_preferenceKeyPrefix.${kind.name}') ??
        const [];
    return encoded
        .map(_decode)
        .whereType<MediaSearchResult>()
        .take(mediaFavoriteLimitPerKind)
        .toList(growable: false);
  }

  @override
  Future<void> save(
    MediaSearchKind kind,
    List<MediaSearchResult> favorites,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      '$_preferenceKeyPrefix.${kind.name}',
      favorites
          .take(mediaFavoriteLimitPerKind)
          .map(_encode)
          .toList(growable: false),
    );
  }

  String _encode(MediaSearchResult result) => jsonEncode({
    'id': result.id,
    'title': result.title,
    'previewUri': result.previewUri.toString(),
    'downloadUri': result.downloadUri.toString(),
    'mimeType': result.mimeType,
    'source': result.source,
    'width': result.width,
    'height': result.height,
  });

  MediaSearchResult? _decode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      final id = value['id'];
      final title = value['title'];
      final previewUri = value['previewUri'];
      final downloadUri = value['downloadUri'];
      final mimeType = value['mimeType'];
      final source = value['source'];
      if (id is! String ||
          title is! String ||
          previewUri is! String ||
          downloadUri is! String ||
          mimeType is! String ||
          source is! String) {
        return null;
      }
      final parsedPreviewUri = Uri.tryParse(previewUri);
      final parsedDownloadUri = Uri.tryParse(downloadUri);
      if (parsedPreviewUri == null || parsedDownloadUri == null) return null;
      return MediaSearchResult(
        id: id,
        title: title,
        previewUri: parsedPreviewUri,
        downloadUri: parsedDownloadUri,
        mimeType: mimeType,
        source: source,
        width: value['width'] as int?,
        height: value['height'] as int?,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

String mediaFavoriteId(MediaSearchResult result) =>
    '${result.source}\u0000${result.id}';

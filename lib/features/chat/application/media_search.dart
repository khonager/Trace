import 'dart:typed_data';

enum MediaSearchKind { gif, sticker }

enum MediaSearchSafety { strict, open }

final class MediaSearchResult {
  const MediaSearchResult({
    required this.id,
    required this.title,
    required this.previewUri,
    required this.downloadUri,
    required this.mimeType,
    required this.source,
    this.width,
    this.height,
  });

  final String id;
  final String title;
  final Uri previewUri;
  final Uri downloadUri;
  final String mimeType;
  final String source;
  final int? width;
  final int? height;
}

final class DownloadedMedia {
  const DownloadedMedia({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

abstract interface class MediaSearchPort {
  bool get isConfigured;

  Future<List<MediaSearchResult>> search({
    required String query,
    required MediaSearchKind kind,
    required MediaSearchSafety safety,
  });

  Future<DownloadedMedia> download(MediaSearchResult result);
}

final class MediaSearchException implements Exception {
  const MediaSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

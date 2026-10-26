import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileHistoryEntry {
  const ProfileHistoryEntry({
    required this.name,
    this.avatar,
    this.thumbnail,
    required this.observedAt,
  });
  final String name;
  final Uri? avatar;
  final Uint8List? thumbnail;
  final DateTime observedAt;
  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar?.toString(),
    'at': observedAt.toIso8601String(),
    if (thumbnail != null) 'thumbnail': base64Encode(thumbnail!),
  };
  factory ProfileHistoryEntry.fromJson(Map<String, dynamic> value) =>
      ProfileHistoryEntry(
        name: value['name'] as String,
        avatar: value['avatar'] == null
            ? null
            : Uri.parse(value['avatar'] as String),
        observedAt: DateTime.parse(value['at'] as String),
        thumbnail: value['thumbnail'] is String
            ? base64Decode(value['thumbnail'] as String)
            : null,
      );
}

/// Opt-in, account-scoped history. Deletion retains the last observed fingerprint
/// so an unchanged sync cannot silently recreate an entry the user removed.
class ProfileHistoryStore extends ChangeNotifier {
  ProfileHistoryStore({
    required String account,
    this.loadThumbnail,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) {
    final key = 'trace.profile_history.v1.$account';
    const storage = FlutterSecureStorage();
    _write = write ?? (value) => storage.write(key: key, value: value);
    ready = (read ?? () => storage.read(key: key))().then((encoded) {
      if (encoded != null) {
        _profiles = jsonDecode(encoded) as Map<String, dynamic>;
      }
    });
    _tail = ready;
  }
  final Future<Uint8List> Function(Uri)? loadThumbnail;
  late final Future<void> ready;
  late Future<void> _tail;
  late final Future<void> Function(String) _write;
  Map<String, dynamic> _profiles = {};
  bool _disposed = false;

  bool enabled(String user) => (_profiles[user] as Map?)?['enabled'] == true;
  List<ProfileHistoryEntry> entries(String user) =>
      (((_profiles[user] as Map?)?['entries'] as List?) ?? [])
          .map(
            (value) => ProfileHistoryEntry.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList()
          .reversed
          .toList();

  Future<void> _change(FutureOr<void> Function() update) {
    final operation = _tail.then((_) async {
      final before = jsonEncode(_profiles);
      try {
        await update();
        await _write(jsonEncode(_profiles));
      } catch (_) {
        _profiles = jsonDecode(before) as Map<String, dynamic>;
        rethrow;
      }
      if (!_disposed) notifyListeners();
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setEnabled(String user, bool value) => _change(() {
    final record =
        _profiles.putIfAbsent(user, () => <String, dynamic>{}) as Map;
    record['enabled'] = value;
  });

  Future<void> observe(String user, String name, Uri? avatar) async {
    await ready;
    if (!enabled(user)) return;
    final fingerprint = jsonEncode([name, avatar?.toString()]);
    if ((_profiles[user] as Map)['last'] == fingerprint) return;
    await _change(() async {
      final record = _profiles[user] as Map;
      if (record['enabled'] != true || record['last'] == fingerprint) return;
      Uint8List? thumbnail;
      if (avatar != null && loadThumbnail != null) {
        try {
          thumbnail = await loadThumbnail!(
            avatar,
          ).timeout(const Duration(seconds: 15));
          // A misbehaving server may return the original instead of a thumbnail.
          if (thumbnail.length > 256 * 1024) thumbnail = null;
        } catch (_) {
          /* Preserve the profile metadata even when offline. */
        }
      }
      record['last'] = fingerprint;
      (record['entries'] ??= <dynamic>[]).add(
        ProfileHistoryEntry(
          name: name,
          avatar: avatar,
          thumbnail: thumbnail,
          observedAt: DateTime.now(),
        ).toJson(),
      );
    });
  }

  Future<void> delete(String user, ProfileHistoryEntry entry) => _change(() {
    ((_profiles[user] as Map?)?['entries'] as List?)?.removeWhere(
      (value) =>
          value['at'] == entry.observedAt.toIso8601String() &&
          value['name'] == entry.name,
    );
  });
  Future<void> clear(String user) => _change(() {
    final record = _profiles[user] as Map?;
    if (record != null) record['entries'] = <dynamic>[];
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

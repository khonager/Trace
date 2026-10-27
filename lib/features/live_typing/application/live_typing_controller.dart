import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LiveTypingHost {
  LiveTypingController get liveTyping;
}

/// The adapter authenticates the device and room membership before delivery.
final class LiveTypingPacket {
  const LiveTypingPacket(this.user, this.device, this.content);
  final String user;
  final String device;
  final Map<String, dynamic> content;
  String get peer => '$user/$device';
}

typedef SendLiveTyping =
    Future<void> Function(
      String room,
      Map<String, dynamic> content,
      LiveTypingPacket? recipient,
    );

/// Drafts live only in memory. A receiver nonce prevents offline queue replay
/// across view sessions. Monotonic sequence numbers reject reordered updates.
final class LiveTypingController extends ChangeNotifier {
  LiveTypingController({required this.send});
  final SendLiveTyping send;
  bool enabled = false;
  final Set<String> excludedRooms = {};
  final Map<String, LiveTypingPacket> _peers = {};
  final Map<String, int> _sequences = {};
  final Map<String, ({String user, String text, int expiry})> _drafts = {};
  String? _account;
  String? _room;
  String? _nonce;
  String _text = '';
  int _sequence = 0;
  int _lastEdit = 0;
  int _lastHello = 0;
  bool _busy = false;
  bool _disposed = false;
  Timer? _timer;
  SharedPreferences? _preferences;
  String get _key => 'trace.live_typing.v1.$_account';
  bool allows(String room) => enabled && !excludedRooms.contains(room);
  String draftFor(String room) => room == _room
      ? _drafts.values.map((d) => '${d.user}: ${d.text}').join('\n')
      : '';

  Future<void> load(String account) async {
    if (_account == account) return;
    leave();
    _account = account;
    enabled = false;
    excludedRooms.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || _account != account) return;
      _preferences = prefs;
      enabled = prefs.getBool('$_key.enabled') ?? false;
      excludedRooms.addAll(prefs.getStringList('$_key.excluded') ?? []);
      notifyListeners();
    } catch (_) {
      /* Fail closed when settings cannot be read. */
    }
  }

  Future<void> configure({bool? global, String? room, bool? allowed}) async {
    final active = _room;
    leave();
    if (global != null) enabled = global;
    if (room != null && allowed != null) {
      allowed ? excludedRooms.remove(room) : excludedRooms.add(room);
    }
    notifyListeners();
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      if (!await prefs.setBool('$_key.enabled', enabled) ||
          !await prefs.setStringList(
            '$_key.excluded',
            excludedRooms.toList(),
          )) {
        throw StateError('Live typing settings could not be saved.');
      }
    } catch (_) {
      // Failed opt-outs must not silently become sharing on next launch.
      enabled = false;
      notifyListeners();
      rethrow;
    }
    if (active != null && !_disposed) enter(active);
  }

  void enter(String room) {
    if (_room == room || !allows(room) || _disposed) return;
    leave();
    _room = room;
    final random = Random.secure();
    _nonce = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _lastHello = 0;
    _timer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => unawaited(_tick()),
    );
    unawaited(_tick());
  }

  void edit(String room, String text) {
    if (_room != room) enter(room);
    if (_room != room) return;
    _text = text.length <= 4096 ? text : text.substring(0, 4096);
    _lastEdit = DateTime.now().millisecondsSinceEpoch;
  }

  void clearDraft() {
    _text = '';
    _lastEdit = 0;
    unawaited(_broadcast(''));
  }

  void leave() {
    _timer?.cancel();
    _timer = null;
    if (_room != null) unawaited(_broadcast(''));
    _room = null;
    _nonce = null;
    _text = '';
    _peers.clear();
    _sequences.clear();
    _drafts.clear();
    if (!_disposed) notifyListeners();
  }

  Future<void> _safeSend(
    String room,
    Map<String, dynamic> data,
    LiveTypingPacket? peer,
  ) async {
    try {
      await send(room, data, peer);
    } catch (_) {
      // Ephemeral traffic is best effort; never retry old drafts.
    }
  }

  Future<void> _tick() async {
    final room = _room;
    if (room == null || !allows(room) || _busy) return;
    _busy = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final previous = _drafts.length;
      _drafts.removeWhere((_, d) => d.expiry <= now);
      _peers.removeWhere((_, p) => (p.content['expires_at'] as int) <= now);
      if (previous != _drafts.length) notifyListeners();
      if (now - _lastHello >= 4000) {
        _lastHello = now;
        await _safeSend(room, {
          'kind': 'hello',
          'nonce': _nonce,
          'expires_at': now + 8000,
        }, null);
      }
      if (_room != room) return;
      await _broadcast(now - _lastEdit < 5000 ? _text : '');
    } finally {
      _busy = false;
    }
  }

  Future<void> _broadcast(String text) async {
    final room = _room;
    if (room == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sequence = ++_sequence;
    for (final peer in _peers.values.toList()) {
      if (_room != room || !allows(room)) return;
      if ((peer.content['expires_at'] as int) <= now) continue;
      await _safeSend(room, {
        'kind': 'draft',
        'nonce': peer.content['nonce'],
        'session': _nonce,
        'sequence': sequence,
        'text': text,
        'expires_at': now + 5000,
      }, peer);
    }
  }

  void receive(LiveTypingPacket packet) {
    final data = packet.content;
    final room = data['room_id'];
    if (_disposed || room != _room || room is! String || !allows(room)) return;
    final expiry = data['expires_at'];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry is! int || expiry <= now || expiry > now + 10000) return;
    final nonce = data['nonce'];
    if (nonce is! String || nonce.length != 48) return;
    if (data['kind'] == 'hello') {
      if (_peers.length >= 64 && !_peers.containsKey(packet.peer)) return;
      _peers[packet.peer] = packet;
      return;
    }
    final sequence = data['sequence'];
    final text = data['text'];
    final session = data['session'];
    if (data['kind'] != 'draft' ||
        nonce != _nonce ||
        sequence is! int ||
        sequence < 0 ||
        text is! String ||
        text.length > 4096 ||
        session is! String ||
        session != _peers[packet.peer]?.content['nonce']) {
      return;
    }
    final key = '${packet.peer}/$session';
    if (sequence <= (_sequences[key] ?? -1)) return;
    if (_sequences.length > 256) return;
    _sequences[key] = sequence;
    if (text.isEmpty) {
      _drafts.remove(packet.peer);
    } else {
      _drafts[packet.peer] = (user: packet.user, text: text, expiry: expiry);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    leave();
    _disposed = true;
    super.dispose();
  }
}

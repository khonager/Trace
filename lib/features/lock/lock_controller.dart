import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum LockMethod { device, biometric, passcode, password, pattern }

extension LockMethodLabel on LockMethod {
  String get label => switch (this) {
    LockMethod.device => 'Device screen lock',
    LockMethod.biometric => 'Biometrics only',
    LockMethod.passcode => 'Custom passcode',
    LockMethod.password => 'Custom password',
    LockMethod.pattern => 'Custom pattern',
  };
  bool get custom => index >= LockMethod.passcode.index;
}

class LockController extends ChangeNotifier {
  LockController({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    Future<bool> Function(bool)? authenticateDevice,
  }) : _read = read ?? (() => const FlutterSecureStorage().read(key: _key)),
       _write =
           write ??
           ((value) =>
               const FlutterSecureStorage().write(key: _key, value: value)),
       _authenticateDevice =
           authenticateDevice ??
           ((biometric) => LocalAuthentication().authenticate(
             localizedReason: 'Unlock Trace',
             biometricOnly: biometric,
             persistAcrossBackgrounding: false,
           ));

  static const app = 'app';
  static const _key = 'trace.locks.v1';
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Future<bool> Function(bool) _authenticateDevice;
  Map<String, dynamic> _rules = {};
  final Set<String> _unlocked = {};
  bool ready = false;
  String? error;
  bool authenticating = false;
  int _epoch = 0;
  String? resumeLock;
  int _failures = 0;
  DateTime? _retryAfter;

  LockMethod? method(String id) => _rules[id] == null
      ? null
      : LockMethod.values.byName(_rules[id]['method'] as String);
  bool enabled(String id) => _rules.containsKey(id);
  bool locked(String id) => enabled(id) && !_unlocked.contains(id);
  bool get hasLocks => _rules.isNotEmpty;

  Future<void> load() async {
    try {
      final raw = await _read();
      final decoded = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      for (final rule in decoded.values) {
        final method = LockMethod.values.byName(rule['method'] as String);
        if (method.custom) {
          if (base64Decode(rule['salt'] as String).length != 16 ||
              base64Decode(rule['hash'] as String).length != 32) {
            throw const FormatException('Invalid lock');
          }
        }
      }
      _rules = decoded;
      ready = true;
      error = null;
    } catch (_) {
      ready = false;
      error =
          'Could not read lock settings. Retry to keep your chats protected.';
    }
    notifyListeners();
  }

  static String? validate(LockMethod method, String secret) => switch (method) {
    LockMethod.passcode when !RegExp(r'^\d+$').hasMatch(secret) =>
      'Enter one or more digits.',
    LockMethod.password when secret.isEmpty => 'Enter a password.',
    LockMethod.pattern
        when secret.isEmpty ||
            secret.length > 9 ||
            !RegExp(r'^[1-9]+$').hasMatch(secret) ||
            secret.split('').toSet().length != secret.length =>
      'Choose one or more different dots.',
    _ => null,
  };

  Future<List<int>> _hash(String secret, List<int> salt) =>
      compute(_deriveVerifier, (secret, salt));

  Future<bool> verify(
    String id, {
    String secret = '',
    LockMethod? candidate,
  }) async {
    if (authenticating || (_retryAfter?.isAfter(DateTime.now()) ?? false)) {
      return false;
    }
    final selected = candidate ?? method(id);
    if (selected == null) return true;
    authenticating = true;
    final epoch = _epoch;
    try {
      bool success;
      if (selected.custom) {
        final rule = _rules[id];
        if (rule == null) return false;
        final actual = await _hash(
          secret,
          base64Decode(rule['salt'] as String),
        );
        final expected = base64Decode(rule['hash'] as String);
        var difference = actual.length ^ expected.length;
        for (var i = 0; i < actual.length && i < expected.length; i++) {
          difference |= actual[i] ^ expected[i];
        }
        success = difference == 0;
      } else {
        success = await _authenticateDevice(selected == LockMethod.biometric);
      }
      if (epoch != _epoch) return false;
      if (success) {
        _failures = 0;
        _retryAfter = null;
        if (candidate == null) _unlocked.add(id);
        if (resumeLock == id) resumeLock = null;
        notifyListeners();
      } else {
        _failures++;
        if (_failures >= 5) {
          _retryAfter = DateTime.now().add(const Duration(seconds: 30));
        }
      }
      return success;
    } catch (_) {
      return false;
    } finally {
      authenticating = false;
    }
  }

  Future<void> configure(
    String id,
    LockMethod? selected, {
    String secret = '',
  }) async {
    if (!ready || locked(id)) {
      throw StateError('Unlock before changing this lock.');
    }
    final updated = Map<String, dynamic>.from(_rules);
    if (selected == null) {
      updated.remove(id);
    } else {
      final validation = validate(selected, secret);
      if (validation != null) throw ArgumentError(validation);
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      updated[id] = <String, dynamic>{
        'method': selected.name,
        if (selected.custom) 'salt': base64Encode(salt),
        if (selected.custom) 'hash': base64Encode(await _hash(secret, salt)),
      };
    }
    await _write(jsonEncode(updated));
    _rules = updated;
    _unlocked.remove(id);
    notifyListeners();
  }

  void lockAll() {
    _epoch++;
    // Cover open media/dialog routes when a previously unlocked chat relocks.
    resumeLock ??= _unlocked
        .where((id) => id != app && enabled(id))
        .firstOrNull;
    _unlocked.clear();
    notifyListeners();
  }
}

Future<List<int>> _deriveVerifier((String, List<int>) input) async =>
    (await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(input.$1)),
          nonce: input.$2,
        ))
        .extractBytes();

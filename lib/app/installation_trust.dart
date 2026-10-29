import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Android keeps this receipt outside OS backup, so a restored session needs
/// local confirmation again after reinstall or device transfer.
class InstallationTrust {
  static const _channel = MethodChannel('chat.trace/installation');
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isConfirmed(String userId) async {
    if (!_android) return true;
    return await _channel.invokeMethod<bool>('isConfirmed', userId) ?? false;
  }

  Future<void> remember(String userId) async {
    if (_android) await _channel.invokeMethod<void>('confirm', userId);
  }

  Future<bool> authenticate() => LocalAuthentication().authenticate(
    localizedReason: 'Confirm it is you before opening restored Trace chats',
    persistAcrossBackgrounding: false,
  );
}

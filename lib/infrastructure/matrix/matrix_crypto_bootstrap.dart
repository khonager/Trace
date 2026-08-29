import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vodozemac;

Future<void>? _initialization;

/// Loads the native vodozemac library used for Matrix end-to-end encryption.
///
/// This is intentionally idempotent so every composition root can safely make
/// encryption a startup prerequisite without loading the library twice.
Future<void> initializeMatrixCrypto() {
  return _initialization ??= vodozemac.init();
}

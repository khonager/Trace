import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vodozemac/vodozemac.dart' as vodozemac;

Future<void>? _initialization;

/// Loads the native vodozemac library used for Matrix end-to-end encryption.
///
/// This is intentionally idempotent so every composition root can safely make
/// encryption a startup prerequisite without loading the library twice.
Future<void> initializeMatrixCrypto() {
  return _initialization ??= vodozemac.init(
    libraryPath: _nativeLibraryPath(),
    stem: !kIsWeb && (Platform.isIOS || Platform.isMacOS)
        ? 'flutter_vodozemac'
        : 'vodozemac_bindings_dart',
  );
}

String _nativeLibraryPath() {
  if (!kIsWeb && Platform.isLinux) {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return '$executableDirectory${Platform.pathSeparator}lib${Platform.pathSeparator}';
  }
  return './';
}

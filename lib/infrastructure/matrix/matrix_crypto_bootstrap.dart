import 'package:trace/infrastructure/matrix/matrix_native_library_stub.dart'
    if (dart.library.io) 'matrix_native_library_io.dart';
import 'package:vodozemac/vodozemac.dart' as vodozemac;

Future<void>? _initialization;

/// Loads the native vodozemac library used for Matrix end-to-end encryption.
///
/// This is intentionally idempotent so every composition root can safely make
/// encryption a startup prerequisite without loading the library twice.
Future<void> initializeMatrixCrypto() {
  return _initialization ??= vodozemac.init(
    wasmPath: './pkg/',
    libraryPath: matrixCryptoLibraryPath,
    stem: matrixCryptoLibraryStem,
  );
}

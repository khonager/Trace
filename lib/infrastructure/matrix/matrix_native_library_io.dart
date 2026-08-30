import 'dart:io';

String get matrixCryptoLibraryPath {
  if (Platform.isLinux) {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return '$executableDirectory${Platform.pathSeparator}lib${Platform.pathSeparator}';
  }
  return './';
}

String get matrixCryptoLibraryStem => Platform.isIOS || Platform.isMacOS
    ? 'flutter_vodozemac'
    : 'vodozemac_bindings_dart';

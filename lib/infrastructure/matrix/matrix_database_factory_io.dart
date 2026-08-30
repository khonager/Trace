import 'dart:io';

import 'package:matrix/matrix.dart' as matrix;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

Future<matrix.DatabaseApi> openMatrixDatabase({
  String profileId = 'default',
}) async {
  if (!Platform.isAndroid && !Platform.isLinux) {
    throw UnsupportedError(
      'Trace currently ships its Matrix database for Android and Linux.',
    );
  }

  final supportDirectory = await getApplicationSupportDirectory();
  await supportDirectory.create(recursive: true);
  final safeProfileId = profileId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final suffix = safeProfileId == 'default' ? '' : '-$safeProfileId';
  final databasePath = path.join(supportDirectory.path, 'matrix$suffix.sqlite');
  final mediaDirectory = Directory(
    path.join(supportDirectory.path, 'media$suffix'),
  );
  await mediaDirectory.create(recursive: true);

  if (Platform.isLinux) {
    desktop.sqfliteFfiInit();
    final database = await desktop.databaseFactoryFfi.openDatabase(
      databasePath,
    );
    return matrix.MatrixSdkDatabase.init(
      'Trace-$safeProfileId',
      database: database,
      sqfliteFactory: desktop.databaseFactoryFfi,
      fileStorageLocation: mediaDirectory.uri,
      deleteFilesAfterDuration: const Duration(days: 7),
    );
  }

  final database = await mobile.openDatabase(databasePath);
  return matrix.MatrixSdkDatabase.init(
    'Trace-$safeProfileId',
    database: database,
    fileStorageLocation: mediaDirectory.uri,
    deleteFilesAfterDuration: const Duration(days: 7),
  );
}

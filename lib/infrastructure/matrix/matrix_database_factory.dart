import 'package:matrix/matrix.dart' as matrix;
import 'package:trace/infrastructure/matrix/matrix_database_factory_stub.dart'
    if (dart.library.io) 'matrix_database_factory_io.dart'
    as platform;

/// Opens Trace's persistent Matrix store for the current platform.
///
/// The Matrix SDK uses IndexedDB directly on web. Native targets receive a
/// SQLite database and a private application-support directory for cached
/// media. The SDK owns migrations and closes the store with the client.
Future<matrix.DatabaseApi> openMatrixDatabase({String profileId = 'default'}) =>
    platform.openMatrixDatabase(profileId: profileId);

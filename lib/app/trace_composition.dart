import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/infrastructure/matrix/matrix_dart_client_adapter.dart';
import 'package:trace/infrastructure/matrix/matrix_database_factory.dart';

Future<MatrixSessionController> createTraceSessionController() async {
  Future<MatrixClientPort> createClient(String profileId) async {
    final database = await openMatrixDatabase(profileId: profileId);
    return MatrixDartClientAdapter(createMatrixDartClient(database: database));
  }

  final controller = MatrixSessionController(
    await createClient('default'),
    clientFactory: createClient,
  );
  await controller.initialize();
  return controller;
}

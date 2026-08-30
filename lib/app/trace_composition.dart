import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/infrastructure/matrix/matrix_dart_client_adapter.dart';
import 'package:trace/infrastructure/matrix/matrix_database_factory.dart';

Future<MatrixSessionController> createTraceSessionController() async {
  final database = await openMatrixDatabase();
  final sdkClient = createMatrixDartClient(database: database);
  final controller = MatrixSessionController(
    MatrixDartClientAdapter(sdkClient),
  );
  await controller.initialize();
  return controller;
}

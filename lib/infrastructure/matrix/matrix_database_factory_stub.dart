import 'package:matrix/matrix.dart' as matrix;

Future<matrix.DatabaseApi> openMatrixDatabase() =>
    matrix.MatrixSdkDatabase.init('Trace');

import 'package:matrix/matrix.dart' as matrix;

Future<matrix.DatabaseApi> openMatrixDatabase({String profileId = 'default'}) =>
    matrix.MatrixSdkDatabase.init('Trace');

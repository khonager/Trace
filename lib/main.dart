import 'package:flutter/widgets.dart';
import 'package:trace/app/trace_app.dart';
import 'package:trace/infrastructure/matrix/matrix_crypto_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeMatrixCrypto();
  runTraceApp();
}

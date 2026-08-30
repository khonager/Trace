import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/app/trace_home_shell.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/auth/presentation/login_page.dart';

/// Starts the replaceable Flutter shell.
///
/// Product and protocol code must not depend on this layer. The visual design
/// is intentionally absent until a design direction has been selected.
void runTraceApp(MatrixSessionController controller) {
  runApp(TraceApp(controller: controller));
}

void runTraceBootstrapError(Object error) {
  runApp(
    MaterialApp(
      title: 'Trace',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44),
                    const SizedBox(height: 16),
                    const Text(
                      'Trace could not start',
                      style: TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your account has not been modified. Restart after resolving the platform or storage error.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key, this.controller});

  /// Null keeps the interaction prototype available to isolated widget tests.
  /// Production always supplies the real Matrix session controller.
  final MatrixSessionController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF202124),
          onPrimary: Colors.white,
          surface: Color(0xFFF7F7F5),
          onSurface: Color(0xFF202124),
          surfaceContainer: Color(0xFFECECEA),
          surfaceContainerHigh: Color(0xFFE3E3E0),
          secondaryContainer: Color(0xFFD7D7D3),
          onSecondaryContainer: Color(0xFF202124),
          outline: Color(0xFFC9C9C5),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFD7D7D3),
          thickness: 0.7,
          space: 1,
        ),
        scaffoldBackgroundColor: const Color(0xFFE9E9E6),
        useMaterial3: true,
      ),
      home: controller == null
          ? const TraceHomeShell()
          : _SessionGate(controller: controller!),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate({required this.controller});

  final MatrixSessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        if (snapshot.isLoggedIn) {
          return TraceHomeShell(controller: controller);
        }
        if (snapshot.phase == MatrixConnectionPhase.starting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LoginPage(controller: controller);
      },
    );
  }
}

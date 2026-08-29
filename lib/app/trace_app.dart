import 'package:flutter/material.dart';
import 'package:trace/app/trace_home_shell.dart';

/// Starts the replaceable Flutter shell.
///
/// Product and protocol code must not depend on this layer. The visual design
/// is intentionally absent until a design direction has been selected.
void runTraceApp() {
  runApp(const TraceApp());
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key});

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
      home: const TraceHomeShell(),
    );
  }
}

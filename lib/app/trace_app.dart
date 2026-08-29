import 'package:flutter/material.dart';

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Trace groundwork ready'))),
    );
  }
}

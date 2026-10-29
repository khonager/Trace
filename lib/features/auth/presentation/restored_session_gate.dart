import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';

class RestoredSessionGate extends StatefulWidget {
  const RestoredSessionGate({
    super.key,
    required this.controller,
    required this.child,
  });
  final MatrixSessionController controller;
  final Widget child;
  @override
  State<RestoredSessionGate> createState() => _RestoredSessionGateState();
}

class _RestoredSessionGateState extends State<RestoredSessionGate> {
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not confirm access. Try again, or sign out and sign in with your account.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      if (!widget.controller.needsSessionConfirmation) return widget.child;
      return Material(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Is this your account?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.controller.snapshot.account?.userId ??
                          'Saved Matrix account',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Android restored a saved Trace session. Confirm with your device screen lock before opening its chats.',
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(error!),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => run(widget.controller.confirmRestoredSession),
                      child: const Text('Yes, unlock my chats'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(widget.controller.logout),
                      child: const Text('Not me — sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

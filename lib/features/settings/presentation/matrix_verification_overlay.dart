import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

class MatrixVerificationOverlay extends StatelessWidget {
  const MatrixVerificationOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  final MatrixSessionController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    child: child,
    builder: (context, child) {
      final verification = controller.activeVerification;
      final snapshot = controller.verificationSnapshot;
      return Stack(
        children: [
          child!,
          if (verification != null && snapshot != null) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            SafeArea(
              child: Center(
                child: _VerificationCard(
                  key: ObjectKey(verification),
                  controller: controller,
                  verification: verification,
                  snapshot: snapshot,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _VerificationCard extends StatefulWidget {
  const _VerificationCard({
    super.key,
    required this.controller,
    required this.verification,
    required this.snapshot,
  });

  final MatrixSessionController controller;
  final MatrixVerificationPort verification;
  final MatrixVerificationSnapshot snapshot;

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  final _recoveryController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _recoveryController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AlertDialog(
          key: const Key('matrix-verification-dialog'),
          title: Text(_title(snapshot.phase)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account: ${snapshot.userId}\n'
                  'Device: ${snapshot.deviceId ?? 'unknown'}',
                ),
                const SizedBox(height: 16),
                _phaseContent(snapshot),
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: _actions(snapshot.phase),
        ),
      ),
    );
  }

  String _title(MatrixVerificationPhase phase) => switch (phase) {
    MatrixVerificationPhase.requested => 'Verification request',
    MatrixVerificationPhase.chooseMethod => 'Verify with emoji',
    MatrixVerificationPhase.compare => 'Do these match?',
    MatrixVerificationPhase.needsRecovery => 'Unlock encryption recovery',
    MatrixVerificationPhase.done => 'Device verified',
    MatrixVerificationPhase.cancelled => 'Verification cancelled',
    MatrixVerificationPhase.error => 'Verification failed',
    MatrixVerificationPhase.waiting => 'Waiting for the other device',
  };

  Widget _phaseContent(MatrixVerificationSnapshot snapshot) {
    switch (snapshot.phase) {
      case MatrixVerificationPhase.requested:
        return const Text(
          'Another Matrix device wants to verify this session. Only accept if you started this request on a device you trust.',
        );
      case MatrixVerificationPhase.chooseMethod:
        return const Text(
          'Trace supports secure emoji and number comparison. Continue, then compare every item on both devices.',
        );
      case MatrixVerificationPhase.waiting:
        return const Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('Keep the other Matrix client open.')),
          ],
        );
      case MatrixVerificationPhase.compare:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Compare these with the other device. If even one differs, choose “They do not match”.',
            ),
            if (snapshot.emojis.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final emoji in snapshot.emojis)
                    SizedBox(
                      width: 54,
                      child: Column(
                        children: [
                          Text(
                            emoji.symbol,
                            style: const TextStyle(fontSize: 30),
                          ),
                          Text(
                            emoji.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (snapshot.numbers.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                snapshot.numbers.join('   '),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        );
      case MatrixVerificationPhase.needsRecovery:
        return TextField(
          controller: _recoveryController,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Recovery key or passphrase',
            border: OutlineInputBorder(),
          ),
        );
      case MatrixVerificationPhase.done:
        return const Text(
          'The cryptographic comparison completed successfully.',
        );
      case MatrixVerificationPhase.cancelled:
      case MatrixVerificationPhase.error:
        return Text(snapshot.message ?? 'The verification did not complete.');
    }
  }

  List<Widget> _actions(MatrixVerificationPhase phase) {
    final verification = widget.verification;
    switch (phase) {
      case MatrixVerificationPhase.requested:
        return [
          TextButton(
            onPressed: _busy ? null : () => _run(verification.reject),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _run(verification.acceptRequest),
            child: const Text('Accept'),
          ),
        ];
      case MatrixVerificationPhase.chooseMethod:
        return [
          TextButton(
            onPressed: _busy ? null : () => _run(verification.reject),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(verification.startEmojiComparison),
            child: const Text('Compare'),
          ),
        ];
      case MatrixVerificationPhase.compare:
        return [
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() => verification.reject(mismatch: true)),
            child: const Text('They do not match'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _run(verification.confirmMatch),
            child: const Text('They match'),
          ),
        ];
      case MatrixVerificationPhase.needsRecovery:
        return [
          TextButton(
            onPressed: _busy ? null : () => _run(verification.reject),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy || _recoveryController.text.trim().isEmpty
                ? null
                : () => _run(
                    () => verification.continueWithRecovery(
                      _recoveryController.text.trim(),
                    ),
                  ),
            child: const Text('Unlock'),
          ),
        ];
      case MatrixVerificationPhase.waiting:
        return [
          TextButton(
            onPressed: _busy ? null : () => _run(verification.reject),
            child: const Text('Cancel'),
          ),
        ];
      case MatrixVerificationPhase.done:
      case MatrixVerificationPhase.cancelled:
      case MatrixVerificationPhase.error:
        return [
          FilledButton(
            onPressed: _busy ? null : widget.controller.dismissVerification,
            child: const Text('Close'),
          ),
        ];
    }
  }
}

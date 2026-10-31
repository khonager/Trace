import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:trace/features/chat/application/voice_recording.dart';

class VoiceMessageDialog extends StatefulWidget {
  const VoiceMessageDialog({super.key, required this.send, this.recorder});
  final Future<void> Function(Uint8List) send;
  final VoiceRecorder? recorder;
  @override
  State<VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<VoiceMessageDialog>
    with WidgetsBindingObserver {
  late final _recording = widget.recorder ?? VoiceRecording();
  Timer? _timer;
  Uint8List? _bytes;
  bool _recordingNow = false;
  bool _busy = false;
  bool _canceled = false;
  int _seconds = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs can temporarily make the app inactive before recording.
    if ((state != AppLifecycleState.resumed && _recordingNow) ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _canceled = true;
      unawaited(_recording.dispose());
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _recording.start();
      if (!mounted || _canceled) {
        await _recording.dispose();
        return;
      }
      setState(() => _recordingNow = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
        if (_seconds >= 300) unawaited(_stop());
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not record. Check microphone permission and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    setState(() {
      _busy = true;
      _recordingNow = false;
    });
    try {
      final bytes = await _recording.stop();
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording failed. Cancel and record again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(_bytes!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not send. Your recording is ready to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _canceled = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_recording.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Voice message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _recordingNow
                ? 'Recording · ${_seconds}s / 300s'
                : _bytes != null
                ? 'Recording ready · ${_seconds}s'
                : 'Record up to 5 minutes. Send when you are ready.',
          ),
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : _recordingNow
              ? _stop
              : _bytes != null
              ? _send
              : _start,
          child: Text(
            _recordingNow
                ? 'Stop recording'
                : _bytes != null
                ? 'Send'
                : 'Record',
          ),
        ),
      ],
    ),
  );
}

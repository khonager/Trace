import 'package:trace/features/chat/application/audio_source.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

class AudioMessage extends StatefulWidget {
  const AudioMessage({super.key, required this.load, required this.name});
  final Future<MatrixAttachmentData> Function() load;
  final String name;
  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage>
    with WidgetsBindingObserver {
  AudioPlayer? _player;
  PrivateAudioSource? _source;
  StreamSubscription<PlayerState>? _states;
  StreamSubscription<Duration>? _positions;
  bool _busy = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _generation++;
      unawaited(_player?.pause());
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final player = _player ??= AudioPlayer();
      _states ??= player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      });
      _positions ??= player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      });
      if (_playing) {
        await player.pause();
      } else if (_source != null) {
        await player.resume();
      } else {
        final data = await widget.load();
        if (!mounted || generation != _generation) return;
        final source = await PrivateAudioSource.create(
          data.bytes,
          data.mimeType,
        );
        if (!mounted || generation != _generation) {
          await source.dispose();
          return;
        }
        await _source?.dispose();
        _source = source;
        await player.play(source.source);
        if (generation != _generation) await player.pause();
      }
    } catch (_) {
      try {
        await _player?.release();
      } catch (_) {
        // The widget may have disposed its player during a pending download.
      }
      await _source?.dispose();
      _source = null;
      if (mounted) {
        setState(() => _error = 'Could not play audio. Tap to retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_states?.cancel());
    unawaited(_positions?.cancel());
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    await _player?.dispose();
    await _source?.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: _playing ? 'Pause audio' : 'Play audio',
        onPressed: _busy ? null : _toggle,
        icon: _busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_playing ? Icons.pause : Icons.play_arrow),
      ),
      Flexible(
        child: Text(
          _error ??
              '${widget.name}\n${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
          maxLines: 3,
        ),
      ),
    ],
  );
}

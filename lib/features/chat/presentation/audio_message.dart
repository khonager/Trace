import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/audio_source.dart';

class AudioMessage extends StatefulWidget {
  const AudioMessage({
    super.key,
    required this.load,
    required this.name,
    this.foreground,
  });

  final Future<MatrixAttachmentData> Function() load;
  final String name;
  final Color? foreground;

  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage>
    with WidgetsBindingObserver {
  AudioPlayer? _player;
  PrivateAudioSource? _source;
  StreamSubscription<PlayerState>? _states;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<Duration>? _durations;
  StreamSubscription<void>? _completes;
  bool _busy = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
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
      _durations ??= player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      });
      _completes ??= player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      });
      if (_playing) {
        await player.pause();
      } else if (_source != null) {
        if (_duration != null && _position >= _duration!) {
          await player.seek(Duration.zero);
          _position = Duration.zero;
        }
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

  Future<void> _seek(double valueMs) async {
    final player = _player;
    if (player == null || _source == null) return;
    final target = Duration(milliseconds: valueMs.round());
    await player.seek(target);
    if (mounted) setState(() => _position = target);
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_states?.cancel());
    unawaited(_positions?.cancel());
    unawaited(_durations?.cancel());
    unawaited(_completes?.cancel());
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    await _player?.dispose();
    await _source?.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.foreground ?? Theme.of(context).colorScheme.onSurface;
    final isVoice =
        widget.name.startsWith('voice-') && widget.name.endsWith('.wav');
    final displayName = isVoice ? 'Voice message' : widget.name;
    final duration = _duration ?? Duration.zero;
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : (_position.inMilliseconds > 0
              ? _position.inMilliseconds.toDouble()
              : 1.0);
    final currentMs = _position.inMilliseconds
        .clamp(0, maxMs.round())
        .toDouble();

    final timeLabel =
        _formatDuration(_position) +
        (duration > Duration.zero ? ' / ${_formatDuration(duration)}' : '');

    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                color: color,
                tooltip: _playing ? 'Pause audio' : 'Play audio',
                onPressed: _busy ? null : _toggle,
                icon: _busy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      _error ?? timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _error != null
                            ? Theme.of(context).colorScheme.error
                            : color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.25),
              thumbColor: color,
            ),
            child: Slider(
              value: currentMs,
              max: maxMs,
              onChanged: _source == null ? null : _seek,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:matrix/matrix.dart' as matrix;
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/calls/application/call_service.dart';
import 'package:trace/features/calls/application/microphone_access.dart';
import 'package:webrtc_interface/webrtc_interface.dart' as interfaces;

/// The SDK owns Matrix signalling, ICE/TURN, glare resolution, and call timers.
/// Trace owns foreground/privacy eligibility and a single visible voice call.
class MatrixCallService extends CallService implements matrix.WebRTCDelegate {
  MatrixCallService(
    this._client, {
    interfaces.MediaDevices? platformMediaDevices,
    Future<rtc.MediaStream> Function(String)? createEmptyStream,
  }) : _platformMediaDevices =
           platformMediaDevices ?? rtc.navigator.mediaDevices,
       _createEmptyStream = createEmptyStream ?? rtc.createLocalMediaStream {
    _media = _VoiceMediaDevices(this);
    runZonedGuarded(
      () {
        _voip = _TraceVoIP(_client, this);
      },
      (_, _) {
        if (!_closed && _session != null) {
          _error =
              'The call could not connect. Check microphone permission and your network.';
          unawaited(end());
        }
      },
    );
  }
  final matrix.Client _client;
  final interfaces.MediaDevices _platformMediaDevices;
  final Future<rtc.MediaStream> Function(String) _createEmptyStream;
  late final matrix.VoIP _voip;
  late final _VoiceMediaDevices _media;
  matrix.CallSession? _session;
  final Map<matrix.CallSession, List<StreamSubscription<dynamic>>> _listeners =
      {};
  final Map<matrix.CallSession, rtc.RTCVideoRenderer> _renderers = {};
  bool _foreground = false;
  bool Function(String) _roomAllowed = (_) => false;
  bool _closed = false;
  bool _busy = false;
  bool _starting = false;
  Future<void>? _ending;
  int _generation = 0;
  String? _error;
  TraceCall? _pending;

  @override
  bool get busy => _busy || _ending != null;
  @override
  String? get error => _error;
  @override
  TraceCall? get current {
    final session = _session;
    if (session == null) return _pending;
    if (session.state == matrix.CallState.kEnded) return null;
    return TraceCall(
      roomId: session.room.id,
      incoming: session.direction == matrix.CallDirection.kIncoming,
      muted: session.isMicrophoneMuted,
      phase: switch (session.state) {
        matrix.CallState.kRinging ||
        matrix.CallState.kInviteSent => CallPhase.ringing,
        matrix.CallState.kConnected => CallPhase.connected,
        matrix.CallState.kEnding || matrix.CallState.kEnded => CallPhase.ending,
        matrix.CallState.kConnecting ||
        matrix.CallState.kCreateAnswer => CallPhase.connecting,
        _ => CallPhase.preparing,
      },
    );
  }

  bool _allowed(String roomId) =>
      !_closed &&
      _foreground &&
      _roomAllowed(roomId) &&
      _client.getRoomById(roomId)?.membership == matrix.Membership.join;
  void _publish() {
    if (!_closed) notifyListeners();
  }

  @override
  void setAvailability({
    required bool foreground,
    required bool Function(String) roomAllowed,
  }) {
    _foreground = foreground;
    _roomAllowed = roomAllowed;
    final call = current;
    if (call != null && !_allowed(call.roomId)) {
      // Invalidate pending microphone/ICE work even if no session exists yet.
      _generation++;
      unawaited(end());
    }
  }

  @override
  Future<void> start(MatrixRoom room) async {
    if (busy || _starting || _session != null || current != null) return;
    if (!canCallRoom(room) || !_allowed(room.id)) return;
    final nativeRoom = _client.getRoomById(room.id);
    if (nativeRoom == null || nativeRoom.summary.mJoinedMemberCount != 2) {
      _error = 'Voice calls need a joined chat with exactly two members.';
      _publish();
      return;
    }
    final generation = ++_generation;
    _busy = true;
    _starting = true;
    _error = null;
    _pending = TraceCall(
      roomId: room.id,
      phase: CallPhase.preparing,
      incoming: false,
    );
    _publish();
    try {
      final session = await _voip.inviteToCall(
        nativeRoom,
        matrix.CallType.kVoice,
        userId: room.directUserId,
      );
      if (generation != _generation || !_allowed(room.id)) {
        await session.hangup(reason: matrix.CallErrorCode.userHangup);
      }
    } catch (_) {
      if (generation == _generation && !_closed) {
        _error =
            'Could not start the call. Check microphone permission and your connection.';
      }
      await _endSession();
    } finally {
      _pending = null;
      _starting = false;
      _busy = false;
      _publish();
    }
  }

  @override
  Future<void> answer() async {
    final session = _session;
    if (_busy ||
        session == null ||
        current?.canAnswer != true ||
        !_allowed(session.room.id)) {
      return;
    }
    final generation = _generation;
    _busy = true;
    _error = null;
    _publish();
    try {
      final stream = await _openMicrophone(session, generation, {
        'audio': true,
        'video': false,
      });
      final previous = session.localUserMediaStream?.stream;
      try {
        await session.addLocalStream(
          stream,
          matrix.SDPStreamMetadataPurpose.Usermedia,
        );
        await session.setMicrophoneMuted(false);
        await previous?.dispose();
        await session.answer();
        if (kIsWeb) {
          for (final remote in session.getRemoteStreams) {
            await _attachRemoteAudio(session, remote);
          }
        }
      } catch (_) {
        await _stopStream(stream);
        rethrow;
      }
      if (generation != _generation || !_allowed(session.room.id)) {
        await session.hangup(reason: matrix.CallErrorCode.userHangup);
      }
    } catch (_) {
      _error =
          'Could not answer. Check microphone permission and try another call.';
      await _endSession();
    } finally {
      _busy = false;
      _publish();
    }
  }

  @override
  Future<void> end() async {
    _generation++;
    _pending = null;
    await _endSession();
    _publish();
  }

  Future<void> _endSession() =>
      _ending ??= _doEndSession().whenComplete(() => _ending = null);

  Future<void> _doEndSession() async {
    final session = _session;
    if (session == null) return;
    // Keep ownership until cleanup completes, so a second call cannot reuse
    // the microphone while the previous session is shutting down.
    try {
      if (session.state == matrix.CallState.kRinging &&
          session.direction == matrix.CallDirection.kIncoming) {
        await session.reject();
      } else if (session.state != matrix.CallState.kEnded &&
          session.state != matrix.CallState.kEnding) {
        await session.hangup(reason: matrix.CallErrorCode.userHangup);
      }
    } catch (_) {
      await session.cleanUp();
    } finally {
      await _release(session);
      if (identical(_session, session)) _session = null;
    }
  }

  @override
  Future<void> toggleMute() async {
    final session = _session;
    if (_busy || session == null || current?.phase != CallPhase.connected) {
      return;
    }
    _busy = true;
    _publish();
    try {
      await session.setMicrophoneMuted(!session.isMicrophoneMuted);
    } catch (_) {
      _error = 'Could not change the microphone. Try again or end the call.';
    } finally {
      _busy = false;
      _publish();
    }
  }

  @override
  void clearError() {
    _error = null;
    _publish();
  }

  @override
  Future<void> registerListeners(matrix.CallSession session) async {
    if (!_allowed(session.room.id) ||
        session.room.summary.mJoinedMemberCount != 2 ||
        session.isGroupCall ||
        session.type != matrix.CallType.kVoice ||
        (_session != null && !identical(_session, session))) {
      return;
    }
    _session = session;
    _pending = null;
    _listeners[session] = [
      session.onCallStateChanged.stream.listen((_) => _publish()),
      session.onStreamAdd.stream.listen((stream) {
        if (kIsWeb && !stream.isLocal()) {
          unawaited(_attachRemoteAudio(session, stream));
        }
      }),
    ];
    _publish();
  }

  Future<void> _attachRemoteAudio(
    matrix.CallSession session,
    matrix.WrappedMediaStream stream,
  ) async {
    // Attaching before Answer can hit browser autoplay restrictions. Start
    // remote playback after the user has accepted and opened their microphone.
    if (session.direction == matrix.CallDirection.kIncoming &&
        !session.answeredByUs) {
      return;
    }
    try {
      final renderer = _renderers.putIfAbsent(
        session,
        rtc.RTCVideoRenderer.new,
      );
      await renderer.initialize();
      if (!_allowed(session.room.id) || !identical(_session, session)) {
        await _release(session);
        return;
      }
      renderer.srcObject = stream.stream;
    } catch (_) {
      _error = 'Could not play call audio. End the call and try again.';
      _publish();
    }
  }

  @override
  Future<void> handleNewCall(matrix.CallSession session) async {
    if (!_allowed(session.room.id) ||
        session.room.summary.mJoinedMemberCount != 2 ||
        session.isGroupCall ||
        session.type != matrix.CallType.kVoice ||
        !identical(_session, session)) {
      await session.reject();
      return;
    }
    _publish();
  }

  Future<void> _release(matrix.CallSession session) async {
    final listeners = _listeners.remove(session) ?? [];
    for (final listener in listeners) {
      await listener.cancel();
    }
    await _renderers.remove(session)?.dispose();
  }

  @override
  Future<void> handleCallEnded(matrix.CallSession session) async {
    await _release(session);
    if (identical(_session, session)) {
      _session = null;
      _pending = null;
      if (session.hangupReason != matrix.CallErrorCode.userHangup &&
          session.hangupReason != matrix.CallErrorCode.answeredElsewhere) {
        _error = switch (session.hangupReason) {
          matrix.CallErrorCode.inviteTimeout =>
            'No answer. Try calling again later.',
          matrix.CallErrorCode.userBusy =>
            'The other person is busy. Try again later.',
          matrix.CallErrorCode.userMediaFailed =>
            'Microphone unavailable. Check permission and try again.',
          _ =>
            'The call could not connect or the connection was lost. Try again.',
        };
      }
    }
    _publish();
  }

  Future<void> close() async {
    _closed = true;
    _foreground = false;
    await end();
    for (final session in _listeners.keys.toList()) {
      await _release(session);
    }
    super.dispose();
  }

  Future<rtc.MediaStream> _openMicrophone(
    matrix.CallSession session,
    int generation,
    Map<String, dynamic> constraints,
  ) => openCallMicrophone(
    allowed: () =>
        generation == _generation &&
        _allowed(session.room.id) &&
        identical(_session, session) &&
        !session.callHasEnded &&
        session.state != matrix.CallState.kEnding,
    open: () =>
        _platformMediaDevices.getUserMedia({...constraints, 'video': false}),
    release: _stopStream,
  );

  static Future<void> _stopStream(rtc.MediaStream stream) async {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  @override
  interfaces.MediaDevices get mediaDevices => _media;
  @override
  Future<rtc.RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) => rtc.createPeerConnection(configuration, constraints);
  @override
  bool get isWeb => kIsWeb;
  @override
  bool get canHandleNewCall =>
      !_closed &&
      _foreground &&
      _session == null &&
      current == null &&
      !_starting &&
      _ending == null;
  @override
  matrix.EncryptionKeyProvider? get keyProvider => null;
  // Incoming calls are presented visually; no custom caller audio is executed.
  @override
  Future<void> playRingtone() async {}
  @override
  Future<void> stopRingtone() async {}
  @override
  Future<void> handleMissedCall(matrix.CallSession session) async {}
  @override
  Future<void> handleNewGroupCall(matrix.GroupCallSession groupCall) async {}
  @override
  Future<void> handleGroupCallEnded(matrix.GroupCallSession groupCall) async {}
}

/// Matrix's incoming setup asks for local media before Answer. An empty stream
/// lets signalling proceed without requesting permission or capturing audio.
class _VoiceMediaDevices extends interfaces.MediaDevices {
  _VoiceMediaDevices(this.owner);
  final MatrixCallService owner;
  @override
  Future<rtc.MediaStream> getUserMedia(Map<String, dynamic> constraints) async {
    final session = owner._session;
    if (session == null || !owner._allowed(session.room.id)) {
      throw StateError('Call is not available.');
    }
    if (session.direction == matrix.CallDirection.kIncoming) {
      return owner._createEmptyStream('trace-incoming-${session.callId}');
    }
    return owner._openMicrophone(session, owner._generation, constraints);
  }

  @override
  Future<rtc.MediaStream> getDisplayMedia(Map<String, dynamic> constraints) =>
      Future.error(UnsupportedError('Screen sharing is not supported.'));
  @override
  Future<List<rtc.MediaDeviceInfo>> enumerateDevices() =>
      owner._platformMediaDevices.enumerateDevices();
  @override
  Future<List<dynamic>> getSources() => enumerateDevices();
}

/// The SDK otherwise retains TURN credentials indefinitely. Refresh for each
/// call so expiry and signing in to another homeserver cannot reuse stale data.
class _TraceVoIP extends matrix.VoIP {
  _TraceVoIP(super.client, super.delegate);

  @override
  Future<List<Map<String, dynamic>>> getIceServers() async {
    try {
      final credentials = await client.getTurnServer();
      return [
        {
          'username': credentials.username,
          'credential': credentials.password,
          'urls': credentials.uris.map((uri) => uri.toString()).toList(),
        },
      ];
    } catch (_) {
      // Same-LAN/direct calls can still work without a configured relay.
      return [];
    }
  }
}

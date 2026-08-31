import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:matrix/encryption.dart' as encryption;
import 'package:matrix/matrix.dart' as matrix;
import 'package:matrix/encryption/utils/crypto_setup_extension.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/infrastructure/matrix/matrix_crypto_bootstrap.dart';

matrix.Client createMatrixDartClient({
  required matrix.DatabaseApi database,
  String clientName = 'Trace',
}) {
  return matrix.Client(
    clientName,
    database: database,
    supportedLoginTypes: const {
      matrix.AuthenticationTypes.password,
      matrix.AuthenticationTypes.sso,
      matrix.AuthenticationTypes.token,
    },
    verificationMethods: const {
      encryption.KeyVerificationMethod.emoji,
      encryption.KeyVerificationMethod.numbers,
    },
    nativeImplementations: matrix.NativeImplementationsIsolate(
      compute,
      vodozemacInit: initializeMatrixCrypto,
    ),
  );
}

final class MatrixDartClientAdapter implements MatrixClientPort {
  MatrixDartClientAdapter(this._client);

  final matrix.Client _client;
  final StreamController<MatrixClientSnapshot> _snapshots =
      StreamController.broadcast();
  final StreamController<MatrixVerificationPort> _verificationRequests =
      StreamController.broadcast();
  final Map<String, _MatrixDartTimeline> _timelines = {};
  final Map<String, Future<Uint8List>> _mediaDownloads = {};
  final Set<_MatrixDartVerification> _verifications = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  MatrixClientSnapshot _current = const MatrixClientSnapshot.starting();
  MatrixConnectionPhase _connectionPhase = MatrixConnectionPhase.starting;
  MatrixAccount? _account;
  bool _initialized = false;
  static const _spaceOrderEventType = 'chat.trace.space_order';

  @override
  MatrixClientSnapshot get current => _current;

  @override
  Stream<MatrixClientSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<MatrixVerificationPort> get verificationRequests =>
      _verificationRequests.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscriptions.addAll([
      _client.onSync.stream.listen((_) => _publish()),
      _client.onSyncStatus.stream.listen(_handleSyncStatus),
      _client.onLoginStateChanged.stream.listen(_handleLoginState),
      _client.onKeyVerificationRequest.stream.listen((request) {
        final verification = _wrapVerification(request);
        if (!_verificationRequests.isClosed) {
          _verificationRequests.add(verification);
        }
      }),
    ]);

    try {
      await _client.init(waitForFirstSync: false);
      if (_client.isLogged()) {
        _connectionPhase = MatrixConnectionPhase.syncing;
        await _refreshAccount();
      } else {
        _connectionPhase = MatrixConnectionPhase.signedOut;
      }
      _publish();
    } catch (error) {
      _publishError(error);
    }
  }

  @override
  Future<void> login(MatrixLoginRequest request) async {
    _connectionPhase = MatrixConnectionPhase.syncing;
    _publish();
    try {
      await _client.checkHomeserver(request.homeserver);
      switch (request) {
        case PasswordLoginRequest():
          await _client.login(
            matrix.AuthenticationTypes.password,
            identifier: matrix.AuthenticationUserIdentifier(user: request.user),
            password: request.password,
            initialDeviceDisplayName: 'Trace',
          );
        case SsoLoginRequest():
          await _client.login(
            matrix.AuthenticationTypes.token,
            token: request.loginToken,
            initialDeviceDisplayName: 'Trace',
          );
      }
      await _refreshAccount();
      _connectionPhase = MatrixConnectionPhase.syncing;
      _publish();
    } catch (error) {
      _connectionPhase = MatrixConnectionPhase.signedOut;
      _publishError(error);
      rethrow;
    }
  }

  @override
  Future<Uri> createSsoLoginUrl({
    required Uri homeserver,
    required Uri callback,
  }) async {
    await _client.checkHomeserver(homeserver);
    final flows = await _client.getLoginFlows() ?? const <matrix.LoginFlow>[];
    final supportsSso = flows.any(
      (flow) => flow.type == matrix.AuthenticationTypes.sso,
    );
    if (!supportsSso) {
      throw Exception('This homeserver does not offer browser sign-in.');
    }
    return homeserver.resolve(
      '_matrix/client/v3/login/sso/redirect?redirectUrl=${Uri.encodeQueryComponent(callback.toString())}',
    );
  }

  @override
  Future<void> logout() async {
    for (final timeline in _timelines.values.toList()) {
      await timeline.close();
    }
    _timelines.clear();
    _mediaDownloads.clear();
    await _client.logout();
    _account = null;
    _connectionPhase = MatrixConnectionPhase.signedOut;
    _publish();
  }

  @override
  Future<MatrixTimelinePort> openTimeline(String roomId) async {
    final existing = _timelines[roomId];
    if (existing != null) return existing;
    final room = _room(roomId);
    late final _MatrixDartTimeline timeline;
    final sdkTimeline = await room.getTimeline(
      onUpdate: () {
        timeline.refresh();
      },
    );
    timeline = _MatrixDartTimeline(
      timeline: sdkTimeline,
      ownUserId: _client.userID ?? '',
      onClose: () => _timelines.remove(roomId),
    );
    _timelines[roomId] = timeline;
    timeline.refresh();
    unawaited(timeline.requestMissingKeys());
    return timeline;
  }

  @override
  Future<void> sendText({
    required String roomId,
    required String body,
    String? replyToEventId,
  }) async {
    final room = _room(roomId);
    final replyTo = replyToEventId == null
        ? null
        : await room.getEventById(replyToEventId);
    await room.sendTextEvent(
      body,
      txid: 'trace-${DateTime.now().microsecondsSinceEpoch}',
      inReplyTo: replyTo,
      displayPendingEvent: true,
    );
  }

  @override
  Future<void> editMessage({
    required String roomId,
    required String eventId,
    required String body,
  }) async {
    await _room(roomId).sendTextEvent(
      body,
      editEventId: eventId,
      txid: 'trace-edit-${DateTime.now().microsecondsSinceEpoch}',
      displayPendingEvent: true,
    );
  }

  @override
  Future<void> react({
    required String roomId,
    required String eventId,
    required String emoji,
  }) async {
    await _room(roomId).sendReaction(
      eventId,
      emoji,
      txid: 'trace-reaction-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  @override
  Future<void> sendFile({
    required String roomId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final file = matrix.MatrixFile.fromMimeType(
      bytes: bytes,
      name: name,
      mimeType: mimeType,
    );
    await _room(roomId).sendFileEvent(
      file,
      txid: 'trace-file-${DateTime.now().microsecondsSinceEpoch}',
      displayPendingEvent: true,
    );
  }

  @override
  Future<void> setTyping(String roomId, bool typing) =>
      _room(roomId).setTyping(typing, timeout: typing ? 5000 : null);

  @override
  Future<void> markRead(String roomId) async {
    final room = _room(roomId);
    final eventId = room.lastEvent?.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      await room.setReadMarker(eventId, mRead: eventId);
    }
  }

  @override
  Future<List<MatrixUser>> searchUsers(String query) async {
    final response = await _client.searchUserDirectory(query, limit: 30);
    return response.results
        .map(
          (profile) => MatrixUser(
            userId: profile.userId,
            displayName: profile.displayName,
            avatarUrl: _mediaUrl(profile.avatarUrl, width: 96, height: 96),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MatrixMessageSearchResult>> searchMessages(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final results = <MatrixMessageSearchResult>[];
    for (final room in _client.rooms.where(
      (room) => room.membership == matrix.Membership.join,
    )) {
      var start = 0;
      const batchSize = 200;
      // Search the cached, already-processed timeline without creating a
      // second plaintext index on disk. Cap each room to keep type-ahead fast.
      while (start < 1000) {
        final events = await _client.database.getEventList(
          room,
          start: start,
          limit: batchSize,
        );
        for (final event in events) {
          if (event.type != matrix.EventTypes.Message) continue;
          final body = event.plaintextBody;
          if (!body.toLowerCase().contains(needle)) continue;
          results.add(
            MatrixMessageSearchResult(
              roomId: room.id,
              roomName: room.getLocalizedDisplayname(),
              eventId: event.eventId,
              senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
              body: body,
              timestamp: event.originServerTs,
            ),
          );
        }
        if (events.length < batchSize) break;
        start += events.length;
      }
    }
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results.take(80).toList(growable: false);
  }

  @override
  Future<String> startDirectChat(String userId) =>
      _client.startDirectChat(userId, enableEncryption: true);

  @override
  Future<String> joinRoom(String roomIdOrAlias) =>
      _client.joinRoom(roomIdOrAlias.trim());

  @override
  Future<String> createSavedMessagesRoom() => _client.createGroupChat(
    groupName: 'Saved Messages',
    enableEncryption: true,
  );

  @override
  Future<String> createGroup({
    required String name,
    List<String> invitees = const [],
  }) => _client.createGroupChat(
    groupName: name,
    enableEncryption: true,
    invite: invitees,
  );

  @override
  Future<void> acceptInvite(String roomId) => _room(roomId).join();

  @override
  Future<void> declineInvite(String roomId) => _room(roomId).leave();

  @override
  Future<void> leaveRoom(String roomId) => _room(roomId).leave();

  @override
  Future<void> setRoomPinned(
    String roomId, {
    required bool pinned,
    double? order,
  }) => pinned
      ? _room(roomId).addTag(matrix.TagType.favourite, order: order)
      : _room(roomId).removeTag(matrix.TagType.favourite);

  @override
  Future<void> setSpaceOrder(List<String> spaceIds) async {
    final userId = _client.userID;
    if (userId == null) throw Exception('Sign in before ordering spaces.');
    await _client.setAccountData(userId, _spaceOrderEventType, {
      'room_ids': spaceIds,
    });
  }

  @override
  Future<Uint8List> downloadMediaThumbnail(
    Uri mxcUri, {
    int width = 96,
    int height = 96,
  }) => _cachedMedia('thumbnail:$width:$height:$mxcUri', () async {
    final mediaId = _matrixMediaId(mxcUri);
    final response = await _client.getContentThumbnail(
      mxcUri.host,
      mediaId,
      width,
      height,
      method: matrix.Method.scale,
      animated: true,
    );
    return response.data;
  });

  @override
  Future<Uint8List> downloadMedia(Uri mxcUri) =>
      _cachedMedia('original:$mxcUri', () async {
        final mediaId = _matrixMediaId(mxcUri);
        final response = await _client.getContent(mxcUri.host, mediaId);
        return response.data;
      });

  String _matrixMediaId(Uri mxcUri) {
    if (!mxcUri.isScheme('mxc') || mxcUri.host.isEmpty) {
      throw Exception('Invalid Matrix media URI.');
    }
    final mediaId = mxcUri.pathSegments.join('/');
    if (mediaId.isEmpty) throw Exception('Invalid Matrix media URI.');
    return mediaId;
  }

  Future<Uint8List> _cachedMedia(
    String key,
    Future<Uint8List> Function() load,
  ) {
    final cached = _mediaDownloads[key];
    if (cached != null) return cached;
    final download = load();
    _mediaDownloads[key] = download;
    unawaited(
      download.then<void>(
        (_) {
          while (_mediaDownloads.length > 128) {
            _mediaDownloads.remove(_mediaDownloads.keys.first);
          }
        },
        onError: (Object _, StackTrace _) {
          _mediaDownloads.remove(key);
        },
      ),
    );
    return download;
  }

  @override
  Future<String> initializeRecovery(String passphrase) =>
      _client.initCryptoIdentity(passphrase: passphrase);

  @override
  Future<void> restoreRecovery(String passphraseOrRecoveryKey) async {
    await _client.restoreCryptoIdentity(passphraseOrRecoveryKey);
    await _requestMissingKeysForOpenTimelines();
  }

  @override
  Future<List<MatrixDevice>> getDevices() async {
    final devices = await _client.getDevices() ?? const <matrix.Device>[];
    final deviceKeys = _client.userDeviceKeys[_client.userID]?.deviceKeys;
    return devices
        .map(
          (device) => MatrixDevice(
            id: device.deviceId,
            name: device.displayName?.trim().isNotEmpty == true
                ? device.displayName!.trim()
                : device.deviceId,
            isCurrent: device.deviceId == _client.deviceID,
            verified: deviceKeys?[device.deviceId]?.verified ?? false,
            lastSeen: device.lastSeenTs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(device.lastSeenTs!),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MatrixVerificationPort> startDeviceVerification(
    String deviceId,
  ) async {
    final userId = _client.userID;
    if (userId == null) throw Exception('Sign in before verifying a device.');
    var key = _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
    if (key == null) {
      await _client.updateUserDeviceKeys(additionalUsers: {userId});
      key = _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
    }
    if (key == null) {
      throw Exception('That Matrix device is no longer available.');
    }
    return _wrapVerification(await key.startVerification());
  }

  _MatrixDartVerification _wrapVerification(
    encryption.KeyVerification request,
  ) {
    final verification = _MatrixDartVerification(
      request,
      onClose: (verification) => _verifications.remove(verification),
      onVerified: _requestMissingKeysForOpenTimelines,
    );
    _verifications.add(verification);
    return verification;
  }

  Future<void> _requestMissingKeysForOpenTimelines() async {
    await Future.wait(
      _timelines.values.map((timeline) => timeline.requestMissingKeys()),
    );
  }

  @override
  Future<void> setForeground(bool foreground) async {
    _client.backgroundSync = foreground;
    if (foreground && _client.isLogged()) {
      await _client.oneShotSync(timeout: Duration.zero);
    }
  }

  matrix.Room _room(String roomId) {
    final room = _client.getRoomById(roomId);
    if (room == null) throw MatrixRoomNotFoundException(roomId);
    return room;
  }

  Future<void> _refreshAccount() async {
    final userId = _client.userID;
    final homeserver = _client.homeserver;
    if (userId == null || homeserver == null) return;
    final profile = await _client.getProfileFromUserId(userId);
    _account = MatrixAccount(
      userId: userId,
      displayName: profile.displayName?.trim().isNotEmpty == true
          ? profile.displayName!.trim()
          : userId,
      homeserver: homeserver,
      deviceId: _client.deviceID,
      avatarUrl: _mediaUrl(profile.avatarUrl, width: 192, height: 192),
    );
  }

  void _handleLoginState(matrix.LoginState state) {
    switch (state) {
      case matrix.LoginState.loggedIn:
        _connectionPhase = MatrixConnectionPhase.syncing;
        unawaited(_refreshAccount().then((_) => _publish()));
      case matrix.LoginState.loggedOut:
        _account = null;
        _connectionPhase = MatrixConnectionPhase.signedOut;
        _publish();
      case matrix.LoginState.softLoggedOut:
        _connectionPhase = MatrixConnectionPhase.softLoggedOut;
        _publish();
    }
  }

  void _handleSyncStatus(matrix.SyncStatusUpdate update) {
    switch (update.status) {
      case matrix.SyncStatus.error:
        _connectionPhase = MatrixConnectionPhase.reconnecting;
      case matrix.SyncStatus.finished:
        _connectionPhase = MatrixConnectionPhase.ready;
      case matrix.SyncStatus.waitingForResponse:
      case matrix.SyncStatus.processing:
      case matrix.SyncStatus.cleaningUp:
        if (_connectionPhase != MatrixConnectionPhase.ready) {
          _connectionPhase = MatrixConnectionPhase.syncing;
        }
    }
    _publish(error: update.error?.toString());
  }

  void _publish({String? error}) {
    final snapshot = MatrixClientSnapshot(
      phase: _connectionPhase,
      account: _account,
      rooms: _client.isLogged() ? _mapRooms() : const [],
      spaceOrder: _spaceOrder,
      error: error,
    );
    _current = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  void _publishError(Object error) {
    final snapshot = MatrixClientSnapshot(
      phase: _account == null
          ? MatrixConnectionPhase.signedOut
          : MatrixConnectionPhase.error,
      account: _account,
      rooms: _client.isLogged() ? _mapRooms() : const [],
      spaceOrder: _spaceOrder,
      error: _friendlyError(error),
    );
    _current = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  List<MatrixRoom> _mapRooms() {
    final rooms = _client.rooms
        .where((room) => room.membership != matrix.Membership.leave)
        .map((room) {
          final lastEvent = room.lastEvent;
          return MatrixRoom(
            id: room.id,
            name: room.getLocalizedDisplayname(),
            preview: lastEvent == null ? '' : _eventPreview(lastEvent),
            timestamp: room.latestEventReceivedTime,
            membership: switch (room.membership) {
              matrix.Membership.invite => MatrixRoomMembership.invited,
              matrix.Membership.leave => MatrixRoomMembership.left,
              _ => MatrixRoomMembership.joined,
            },
            unreadCount: room.notificationCount,
            encrypted: room.encrypted,
            isDirect: room.isDirectChat,
            directUserId: room.directChatMatrixID,
            avatarUrl: _mediaUrl(room.avatar, width: 256, height: 256),
            avatarMediaUri: room.avatar,
            typingUsers: room.typingUsers
                .where((user) => user.id != _client.userID)
                .map((user) => user.calcDisplayname())
                .toList(growable: false),
            isSpace: room.isSpace,
            childRoomIds: room.isSpace
                ? room.spaceChildren
                      .map((child) => child.roomId)
                      .whereType<String>()
                      .toList(growable: false)
                : const [],
            isPinned: room.isFavourite,
            pinOrder: room.tags[matrix.TagType.favourite]?.order,
          );
        })
        .toList(growable: false);
    rooms.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return rooms;
  }

  List<String> get _spaceOrder {
    final ids = _client.accountData[_spaceOrderEventType]?.content['room_ids'];
    return ids is List
        ? ids.whereType<String>().toList(growable: false)
        : const [];
  }

  String _eventPreview(matrix.Event event) {
    final body = event.plaintextBody;
    return switch (event.messageType) {
      matrix.MessageTypes.Image => 'Photo · $body',
      matrix.MessageTypes.Video => 'Video · $body',
      matrix.MessageTypes.Audio => 'Audio · $body',
      matrix.MessageTypes.File => 'File · $body',
      _ => body,
    };
  }

  Uri? _mediaUrl(Uri? mxc, {required int width, required int height}) {
    if (mxc == null) return null;
    if (!mxc.isScheme('mxc')) return mxc;
    // Room snapshots are synchronous; the SDK's authenticated-media helper is
    // asynchronous. This fallback remains valid for homeservers exposing the
    // standard media endpoint and will be replaced by cached authenticated
    // media URLs when that SDK API becomes snapshot-friendly.
    // ignore: deprecated_member_use
    return mxc.getThumbnail(
      _client,
      width: width,
      height: height,
      method: matrix.ThumbnailMethod.crop,
      animated: true,
    );
  }

  String _friendlyError(Object error) {
    if (error is matrix.MatrixException) {
      return error.errorMessage;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Future<void> close() async {
    for (final timeline in _timelines.values.toList()) {
      await timeline.close();
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final verification in _verifications.toList()) {
      await verification.close();
    }
    await _client.dispose();
    await _snapshots.close();
    await _verificationRequests.close();
  }
}

final class _MatrixDartVerification implements MatrixVerificationPort {
  _MatrixDartVerification(
    this._request, {
    required void Function(_MatrixDartVerification verification) onClose,
    required Future<void> Function() onVerified,
  }) : _onClose = onClose,
       _onVerified = onVerified {
    _request.onUpdate = _emit;
  }

  final encryption.KeyVerification _request;
  final void Function(_MatrixDartVerification verification) _onClose;
  final Future<void> Function() _onVerified;
  final StreamController<MatrixVerificationSnapshot> _updates =
      StreamController.broadcast();
  bool _closed = false;
  bool _requestedMissingKeys = false;

  @override
  MatrixVerificationSnapshot get current {
    final comparing = _request.state == encryption.KeyVerificationState.askSas;
    final sasTypes = comparing ? _request.sasTypes : const <String>[];
    final phase = switch (_request.state) {
      encryption.KeyVerificationState.askAccept =>
        MatrixVerificationPhase.requested,
      encryption.KeyVerificationState.askChoice =>
        MatrixVerificationPhase.chooseMethod,
      encryption.KeyVerificationState.askSas => MatrixVerificationPhase.compare,
      encryption.KeyVerificationState.askSSSS =>
        MatrixVerificationPhase.needsRecovery,
      encryption.KeyVerificationState.done => MatrixVerificationPhase.done,
      encryption.KeyVerificationState.error when _request.canceled =>
        MatrixVerificationPhase.cancelled,
      encryption.KeyVerificationState.error => MatrixVerificationPhase.error,
      encryption.KeyVerificationState.waitingAccept ||
      encryption.KeyVerificationState.waitingSas ||
      encryption.KeyVerificationState.showQRSuccess ||
      encryption.KeyVerificationState.confirmQRScan =>
        MatrixVerificationPhase.waiting,
    };
    return MatrixVerificationSnapshot(
      phase: phase,
      userId: _request.userId,
      deviceId: _request.deviceId,
      emojis: sasTypes.contains('emoji')
          ? _request.sasEmojis
                .map(
                  (emoji) => MatrixVerificationEmoji(
                    symbol: emoji.emoji,
                    name: emoji.name,
                  ),
                )
                .toList(growable: false)
          : const [],
      numbers: sasTypes.contains('decimal') ? _request.sasNumbers : const [],
      message: _request.canceledReason,
    );
  }

  @override
  Stream<MatrixVerificationSnapshot> get updates => _updates.stream;

  void _emit() {
    if (_closed) return;
    final snapshot = current;
    _updates.add(snapshot);
    if (snapshot.phase == MatrixVerificationPhase.done &&
        !_requestedMissingKeys) {
      _requestedMissingKeys = true;
      unawaited(_onVerified());
    }
  }

  @override
  Future<void> acceptRequest() => _request.acceptVerification();

  @override
  Future<void> startEmojiComparison() =>
      _request.continueVerification(matrix.EventTypes.Sas);

  @override
  Future<void> confirmMatch() => _request.acceptSas();

  @override
  Future<void> reject({bool mismatch = false}) async {
    if (mismatch) {
      await _request.rejectSas();
    } else if (_request.state == encryption.KeyVerificationState.askAccept) {
      await _request.rejectVerification();
    } else if (!_request.isDone) {
      await _request.cancel('m.user');
    }
  }

  @override
  Future<void> continueWithRecovery(String recoveryKeyOrPassphrase) =>
      _request.openSSSS(keyOrPassphrase: recoveryKeyOrPassphrase);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _request.onUpdate = null;
    _onClose(this);
    await _updates.close();
  }
}

final class _MatrixDartTimeline implements MatrixTimelinePort {
  _MatrixDartTimeline({
    required matrix.Timeline timeline,
    required String ownUserId,
    required void Function() onClose,
  }) : _timeline = timeline,
       _ownUserId = ownUserId,
       _onClose = onClose;

  final matrix.Timeline _timeline;
  final String _ownUserId;
  final void Function() _onClose;
  final Map<String, _TimelineSender> _senders = {};
  final Set<String> _senderLoads = {};
  final Map<String, _TimelineReply> _replies = {};
  final Set<String> _replyLoads = {};
  final StreamController<List<MatrixMessage>> _updates =
      StreamController.broadcast();
  List<MatrixMessage> _current = const [];
  bool _closed = false;

  @override
  List<MatrixMessage> get current => _current;

  @override
  Stream<List<MatrixMessage>> get updates => _updates.stream;

  @override
  bool get canLoadOlder => _timeline.canRequestHistory;

  void refresh() {
    if (_closed) return;
    _current = _timeline.events
        .where(_shouldShow)
        .map(_mapEvent)
        .toList(growable: false);
    _updates.add(_current);
  }

  bool _shouldShow(matrix.Event event) =>
      event.type == matrix.EventTypes.Message ||
      event.type == matrix.EventTypes.Encrypted ||
      event.type == matrix.EventTypes.RoomName ||
      event.type == matrix.EventTypes.RoomTopic;

  MatrixMessage _mapEvent(matrix.Event event) {
    final undecryptable = event.type == matrix.EventTypes.Encrypted;
    final system = event.type != matrix.EventTypes.Message && !undecryptable;
    final sender = event.senderFromMemoryOrFallback;
    final loadedSender = _senders[event.senderId];
    if (_senderLoads.add(event.senderId)) unawaited(_loadSender(event));
    final replyToEventId = undecryptable ? null : event.inReplyToEventId();
    final reply = replyToEventId == null ? null : _replyPreview(replyToEventId);
    if (replyToEventId != null &&
        reply == null &&
        _replyLoads.add(replyToEventId)) {
      unawaited(_loadReply(event, replyToEventId));
    }
    return MatrixMessage(
      eventId: event.eventId,
      senderId: event.senderId,
      senderName: loadedSender?.name ?? sender.calcDisplayname(),
      senderAvatarUrl: loadedSender?.avatarUrl ?? sender.avatarUrl,
      body: undecryptable
          ? 'Unable to decrypt this message.'
          : system
          ? event.calcLocalizedBodyFallback(
              const matrix.MatrixDefaultLocalizations(),
              plaintextBody: true,
            )
          : event.plaintextBody,
      timestamp: event.originServerTs,
      sentByMe: event.senderId == _ownUserId,
      delivery: switch (event.status) {
        matrix.EventStatus.sending => MatrixMessageDelivery.sending,
        matrix.EventStatus.sent => MatrixMessageDelivery.sent,
        matrix.EventStatus.error => MatrixMessageDelivery.failed,
        matrix.EventStatus.synced => MatrixMessageDelivery.synced,
      },
      kind: switch (event.messageType) {
        matrix.MessageTypes.Image => MatrixMessageKind.image,
        matrix.MessageTypes.Video => MatrixMessageKind.video,
        matrix.MessageTypes.Audio => MatrixMessageKind.audio,
        matrix.MessageTypes.File => MatrixMessageKind.file,
        _ => MatrixMessageKind.text,
      },
      attachmentName: event.hasAttachment ? event.plaintextBody : null,
      attachmentMimeType: event.hasAttachment ? event.attachmentMimetype : null,
      attachmentSize: event.hasAttachment
          ? event.infoMap['size'] as int?
          : null,
      attachmentWidth: event.hasAttachment
          ? (event.infoMap['w'] as num?)?.toInt()
          : null,
      attachmentHeight: event.hasAttachment
          ? (event.infoMap['h'] as num?)?.toInt()
          : null,
      isSystem: system,
      isUndecryptable: undecryptable,
      canRequestKey:
          undecryptable && event.content['can_request_session'] == true,
      reactionByMe: _ownReaction(event),
      replyToEventId: replyToEventId,
      replyToSenderName: reply?.senderName,
      replyToBody: reply?.body,
    );
  }

  _TimelineReply? _replyPreview(String eventId) {
    for (final event in _timeline.events) {
      if (event.eventId == eventId) return _cacheReply(event);
    }
    return _replies[eventId];
  }

  _TimelineReply _cacheReply(matrix.Event event) {
    final displayEvent = event.getDisplayEvent(_timeline);
    final sender = displayEvent.senderFromMemoryOrFallback;
    final reply = _TimelineReply(
      senderName: sender.calcDisplayname(),
      body: displayEvent.type == matrix.EventTypes.Encrypted
          ? 'Encrypted message'
          : displayEvent.plaintextBody,
    );
    _replies[event.eventId] = reply;
    return reply;
  }

  Future<void> _loadReply(matrix.Event event, String replyToEventId) async {
    try {
      final replyEvent = await event.getReplyEvent(_timeline);
      if (replyEvent == null || _closed) return;
      _cacheReply(replyEvent);
      refresh();
    } catch (_) {
      // Keep the relation visible even when its target is outside available
      // history or cannot be decrypted yet.
    }
  }

  String? _ownReaction(matrix.Event event) {
    for (final reaction in event.aggregatedEvents(
      _timeline,
      matrix.RelationshipTypes.reaction,
    )) {
      if (reaction.senderId != _ownUserId || reaction.redacted) continue;
      final relatesTo = reaction.content['m.relates_to'];
      if (relatesTo is! Map) continue;
      final key = relatesTo['key'];
      if (key is String && key.isNotEmpty) return key;
    }
    return null;
  }

  Future<void> _loadSender(matrix.Event event) async {
    try {
      final sender = await event.fetchSenderUser();
      if (sender == null || _closed) return;
      _senders[event.senderId] = _TimelineSender(
        name: sender.calcDisplayname(),
        avatarUrl: sender.avatarUrl,
      );
      refresh();
    } catch (_) {
      // The synchronous room-member fallback remains usable when profile
      // lookup is unavailable or the sender has left the room.
    }
  }

  @override
  Future<MatrixAttachmentData> downloadAttachment(
    String eventId, {
    bool thumbnail = false,
  }) async {
    final event = _timeline.events.firstWhere(
      (event) => event.eventId == eventId,
    );
    final file = await event.downloadAndDecryptAttachment(
      getThumbnail: thumbnail,
    );
    return MatrixAttachmentData(
      bytes: file.bytes,
      name: file.name,
      mimeType: file.mimeType,
    );
  }

  @override
  Future<void> loadOlder() async {
    await _timeline.requestHistory(historyCount: 40);
    refresh();
  }

  @override
  Future<void> retry(String eventId) async {
    final event = _timeline.events.firstWhere(
      (event) => event.eventId == eventId,
    );
    await event.sendAgain();
  }

  @override
  Future<void> requestKey(String eventId) async {
    final event = _timeline.events.firstWhere(
      (event) => event.eventId == eventId,
    );
    await event.requestKey();
  }

  @override
  Future<void> toggleReaction(String eventId, String emoji) async {
    final key = emoji.trim();
    if (key.isEmpty) throw ArgumentError.value(emoji, 'emoji', 'is empty');
    try {
      await _timeline.fetchAggregatedEvents(
        eventId,
        matrix.RelationshipTypes.reaction,
      );
    } catch (_) {
      // The synced aggregation is still enough to add or change a reaction
      // when an older homeserver cannot serve the relations endpoint.
    }
    final event = _timeline.events.firstWhere(
      (event) => event.eventId == eventId,
    );
    final ownReactions = event
        .aggregatedEvents(_timeline, matrix.RelationshipTypes.reaction)
        .where((reaction) => reaction.senderId == _ownUserId)
        .where((reaction) => !reaction.redacted)
        .toList(growable: false);
    final alreadySelected = ownReactions.any(
      (reaction) => _reactionKey(reaction) == key,
    );

    if (!alreadySelected) {
      await _timeline.room.sendReaction(
        eventId,
        key,
        txid: 'trace-reaction-${DateTime.now().microsecondsSinceEpoch}',
      );
    }
    for (final reaction in ownReactions) {
      await reaction.redactEvent();
    }
  }

  String? _reactionKey(matrix.Event reaction) {
    final relatesTo = reaction.content['m.relates_to'];
    if (relatesTo is! Map) return null;
    final key = relatesTo['key'];
    return key is String ? key : null;
  }

  Future<void> requestMissingKeys() async {
    final requestedSessions = <String>{};
    for (final event in _timeline.events) {
      if (event.type != matrix.EventTypes.Encrypted ||
          event.messageType != matrix.MessageTypes.BadEncrypted ||
          event.content['can_request_session'] != true) {
        continue;
      }
      final sessionId = event.content['session_id'] as String?;
      if (sessionId == null || !requestedSessions.add(sessionId)) continue;
      try {
        await event.requestKey();
      } catch (_) {
        // A missing key may be absent from backup and offline devices. Keep
        // the placeholder visible; users can retry the individual event.
      }
    }
  }

  @override
  Future<void> redact(String eventId, {String? reason}) async {
    final event = _timeline.events.firstWhere(
      (event) => event.eventId == eventId,
    );
    await event.redactEvent(reason: reason);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timeline.cancelSubscriptions();
    _onClose();
    await _updates.close();
  }
}

final class _TimelineSender {
  const _TimelineSender({required this.name, this.avatarUrl});

  final String name;
  final Uri? avatarUrl;
}

final class _TimelineReply {
  const _TimelineReply({required this.senderName, required this.body});

  final String senderName;
  final String body;
}

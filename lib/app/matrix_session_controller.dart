import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:url_launcher/url_launcher.dart';

class MatrixSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  MatrixSessionController(
    this.client, {
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    Future<MatrixClientPort> Function(String profileId)? clientFactory,
  }) : _secureStorage = secureStorage,
       _clientFactory = clientFactory;

  MatrixClientPort client;
  final FlutterSecureStorage _secureStorage;
  final Future<MatrixClientPort> Function(String profileId)? _clientFactory;
  final Map<String, String> _volatileStorage = {};
  StreamSubscription<MatrixClientSnapshot>? _subscription;
  StreamSubscription<MatrixVerificationPort>? _verificationRequestSubscription;
  StreamSubscription<MatrixVerificationSnapshot>? _verificationSubscription;
  StreamSubscription<MatrixRoomKeyRequestPort>? _roomKeyRequestSubscription;
  final List<MatrixVerificationPort> _verificationQueue = [];
  final List<MatrixRoomKeyRequestPort> _roomKeyRequestQueue = [];
  MatrixVerificationPort? _activeVerification;
  MatrixVerificationSnapshot? _verificationSnapshot;
  MatrixRoomKeyRequestPort? _activeRoomKeyRequest;
  MatrixClientSnapshot _snapshot = const MatrixClientSnapshot.starting();
  bool _busy = false;
  String? _actionError;
  bool _disposed = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  List<MatrixSavedProfile> _savedProfiles = const [];
  String _activeProfileId = 'default';
  String? _returnProfileId;
  bool _addingProfile = false;

  MatrixClientSnapshot get snapshot => _snapshot;
  bool get busy => _busy;
  String? get actionError => _actionError;
  MatrixVerificationPort? get activeVerification => _activeVerification;
  MatrixVerificationSnapshot? get verificationSnapshot => _verificationSnapshot;
  MatrixRoomKeyRequestPort? get activeRoomKeyRequest => _activeRoomKeyRequest;
  List<MatrixSavedProfile> get savedProfiles => _savedProfiles;
  String get activeProfileId => _activeProfileId;
  bool get addingProfile => _addingProfile;
  bool get canCancelProfileLogin =>
      _addingProfile && _returnProfileId != null && _savedProfiles.isNotEmpty;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadProfiles();
    final storedActive = await _readHint(key: 'active_profile_id');
    if (storedActive != null &&
        storedActive != _activeProfileId &&
        _savedProfiles.any((profile) => profile.id == storedActive) &&
        _clientFactory != null) {
      await client.close();
      client = await _clientFactory(storedActive);
      _activeProfileId = storedActive;
    }
    _bindClient();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleLoginCallback,
      onError: (Object error) {
        _actionError = 'Could not read the Matrix sign-in callback.';
        if (!_disposed) notifyListeners();
      },
    );
    await client.initialize();
    _snapshot = client.current;
    await _rememberCurrentAccount();
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) await _handleLoginCallback(initialLink);
    } catch (_) {
      // Deep links are optional on platforms without an app-link handler.
    }
    notifyListeners();
  }

  void _bindClient() {
    _subscription = client.snapshots.listen((snapshot) {
      _snapshot = snapshot;
      if (snapshot.account != null) unawaited(_rememberCurrentAccount());
      if (!_disposed) notifyListeners();
    });
    _verificationRequestSubscription = client.verificationRequests.listen(
      _queueVerification,
    );
    _roomKeyRequestSubscription = client.roomKeyRequests.listen(
      _queueRoomKeyRequest,
    );
  }

  Future<void> beginSso(String homeserver) async {
    await _perform(() async {
      final homeserverUri = normalizeHomeserver(homeserver);
      final callbackBase = kIsWeb
          ? Uri.base.replace(query: '', fragment: '')
          : Uri.parse('trace://login');
      final callback = callbackBase.replace(
        queryParameters: {'traceHomeserver': homeserverUri.toString()},
      );
      final loginUrl = await client.createSsoLoginUrl(
        homeserver: homeserverUri,
        callback: callback,
      );
      await _writeHint(
        key: 'pending_sso_homeserver',
        value: homeserverUri.toString(),
      );
      if (!await launchUrl(loginUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the browser for Matrix sign-in.');
      }
    });
  }

  Future<void> _handleLoginCallback(Uri uri) async {
    final token = uri.queryParameters['loginToken'];
    if (token == null || token.isEmpty || client.current.isLoggedIn) return;
    final pendingHomeserver =
        uri.queryParameters['traceHomeserver'] ??
        await _readHint(key: 'pending_sso_homeserver');
    if (pendingHomeserver == null) return;
    try {
      await client.login(
        SsoLoginRequest(
          homeserver: Uri.parse(pendingHomeserver),
          loginToken: token,
        ),
      );
      await _deleteHint('pending_sso_homeserver');
    } catch (error) {
      _actionError = error.toString().replaceFirst('Exception: ', '');
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> login({
    required String homeserver,
    required String user,
    required String password,
  }) async {
    await _perform(() async {
      final homeserverUri = normalizeHomeserver(homeserver, user: user);
      await client.login(
        PasswordLoginRequest(
          homeserver: homeserverUri,
          user: user.trim(),
          password: password,
        ),
      );
      await _writeHint(key: 'last_homeserver', value: homeserverUri.toString());
      await _writeHint(key: 'last_user', value: user.trim());
      _addingProfile = false;
      await _rememberCurrentAccount();
    });
  }

  Future<void> logout() => _perform(() async {
    final removedId = _activeProfileId;
    await client.logout();
    await _clearVerifications();
    await _clearRoomKeyRequests();
    _savedProfiles = _savedProfiles
        .where((profile) => profile.id != removedId)
        .toList(growable: false);
    await _saveProfiles();
    await _deleteHint('last_user');
    if (_savedProfiles.isNotEmpty && _clientFactory != null) {
      await _activateProfile(_savedProfiles.first.id);
    } else {
      _addingProfile = false;
      _returnProfileId = null;
      await _deleteHint('active_profile_id');
    }
  });

  Future<void> addProfile() => _perform(() async {
    if (_clientFactory == null) {
      throw Exception('Multiple profiles are not available on this platform.');
    }
    _returnProfileId = _snapshot.account == null ? null : _activeProfileId;
    _addingProfile = true;
    final id = 'profile-${DateTime.now().microsecondsSinceEpoch}';
    await _activateProfile(id, persistSelection: false);
  });

  Future<void> cancelProfileLogin() => _perform(() async {
    final returnId = _returnProfileId;
    if (!_addingProfile || returnId == null) return;
    _addingProfile = false;
    _returnProfileId = null;
    await _activateProfile(returnId);
  });

  Future<void> switchProfile(String profileId) => _perform(() async {
    if (profileId == _activeProfileId ||
        !_savedProfiles.any((profile) => profile.id == profileId)) {
      return;
    }
    _addingProfile = false;
    _returnProfileId = null;
    await _activateProfile(profileId);
  });

  Future<void> _activateProfile(
    String profileId, {
    bool persistSelection = true,
  }) async {
    final factory = _clientFactory;
    if (factory == null) throw Exception('Profile switching is unavailable.');
    _snapshot = const MatrixClientSnapshot.starting();
    notifyListeners();
    await _subscription?.cancel();
    _subscription = null;
    await _verificationRequestSubscription?.cancel();
    _verificationRequestSubscription = null;
    await _roomKeyRequestSubscription?.cancel();
    _roomKeyRequestSubscription = null;
    await _clearVerifications();
    await _clearRoomKeyRequests();
    await client.close();
    client = await factory(profileId);
    _activeProfileId = profileId;
    _bindClient();
    await client.initialize();
    _snapshot = client.current;
    if (persistSelection) {
      await _writeHint(key: 'active_profile_id', value: profileId);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadProfiles() async {
    final encoded = await _readHint(key: 'saved_profiles');
    if (encoded == null || encoded.isEmpty) return;
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      _savedProfiles = values
          .whereType<Map<String, dynamic>>()
          .map(MatrixSavedProfile.fromJson)
          .toList(growable: false);
    } catch (_) {
      _savedProfiles = const [];
    }
  }

  Future<void> _rememberCurrentAccount() async {
    final account = client.current.account;
    if (account == null) return;
    final profile = MatrixSavedProfile(
      id: _activeProfileId,
      userId: account.userId,
      displayName: account.displayName,
      homeserver: account.homeserver,
      avatarUrl: account.avatarUrl,
    );
    final existing = _savedProfiles
        .where((saved) => saved.id == profile.id)
        .firstOrNull;
    final alreadyFirst =
        _savedProfiles.isNotEmpty && _savedProfiles.first.id == profile.id;
    if (alreadyFirst &&
        existing?.userId == profile.userId &&
        existing?.displayName == profile.displayName &&
        existing?.homeserver == profile.homeserver &&
        existing?.avatarUrl == profile.avatarUrl) {
      return;
    }
    _savedProfiles = [
      profile,
      ..._savedProfiles.where((saved) => saved.id != profile.id),
    ];
    await _saveProfiles();
    await _writeHint(key: 'active_profile_id', value: _activeProfileId);
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveProfiles() => _writeHint(
    key: 'saved_profiles',
    value: jsonEncode(
      _savedProfiles.map((profile) => profile.toJson()).toList(),
    ),
  );

  Future<void> startDeviceVerification(String deviceId) async {
    final verification = await client.startDeviceVerification(deviceId);
    _queueVerification(verification);
  }

  void _queueVerification(MatrixVerificationPort verification) {
    if (_activeVerification == null) {
      _showVerification(verification);
    } else {
      _verificationQueue.add(verification);
    }
  }

  void _showVerification(MatrixVerificationPort verification) {
    _activeVerification = verification;
    _verificationSnapshot = verification.current;
    _verificationSubscription = verification.updates.listen((snapshot) {
      _verificationSnapshot = snapshot;
      if (!_disposed) notifyListeners();
    });
    if (!_disposed) notifyListeners();
  }

  Future<void> dismissVerification() async {
    await _verificationSubscription?.cancel();
    _verificationSubscription = null;
    await _activeVerification?.close();
    _activeVerification = null;
    _verificationSnapshot = null;
    if (_verificationQueue.isNotEmpty) {
      _showVerification(_verificationQueue.removeAt(0));
    } else if (!_disposed) {
      notifyListeners();
    }
  }

  void _queueRoomKeyRequest(MatrixRoomKeyRequestPort request) {
    if (_activeRoomKeyRequest == null) {
      _activeRoomKeyRequest = request;
    } else {
      _roomKeyRequestQueue.add(request);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> shareActiveRoomKey() async {
    final request = _activeRoomKeyRequest;
    if (request == null) return;
    await request.share();
    _advanceRoomKeyRequest();
  }

  Future<void> rejectActiveRoomKey() async {
    final request = _activeRoomKeyRequest;
    if (request == null) return;
    await request.reject();
    _advanceRoomKeyRequest();
  }

  void _advanceRoomKeyRequest() {
    _activeRoomKeyRequest = _roomKeyRequestQueue.isEmpty
        ? null
        : _roomKeyRequestQueue.removeAt(0);
    if (!_disposed) notifyListeners();
  }

  Future<void> _clearVerifications() async {
    await _verificationSubscription?.cancel();
    _verificationSubscription = null;
    await _activeVerification?.close();
    for (final verification in _verificationQueue) {
      await verification.close();
    }
    _verificationQueue.clear();
    _activeVerification = null;
    _verificationSnapshot = null;
  }

  Future<void> _clearRoomKeyRequests() async {
    final requests = _roomKeyRequestQueue.toList(growable: true);
    final activeRequest = _activeRoomKeyRequest;
    if (activeRequest != null) requests.insert(0, activeRequest);
    _activeRoomKeyRequest = null;
    _roomKeyRequestQueue.clear();
    for (final request in requests) {
      await request.reject();
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _actionError = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> readLastHomeserver() => _readHint(key: 'last_homeserver');

  Future<String?> readLastUser() => _readHint(key: 'last_user');

  // These values are convenience hints, not Matrix credentials. Linux may be
  // running without a Secret Service (for example a minimal compositor), so a
  // missing keyring must never prevent Trace from starting or signing in.
  Future<String?> _readHint({required String key}) async {
    try {
      return await _secureStorage.read(key: key) ?? _volatileStorage[key];
    } catch (_) {
      return _volatileStorage[key];
    }
  }

  Future<void> _writeHint({required String key, required String value}) async {
    _volatileStorage[key] = value;
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      // Keep the value for this process when the platform keyring is absent.
    }
  }

  Future<void> _deleteHint(String key) async {
    _volatileStorage.remove(key);
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // There is nothing persistent to remove when the keyring is absent.
    }
  }

  static Uri normalizeHomeserver(String value, {String? user}) {
    var input = value.trim();
    if (input.isEmpty && user != null) {
      final separator = user.lastIndexOf(':');
      if (separator > 0 && separator < user.length - 1) {
        input = user.substring(separator + 1);
      }
    }
    if (input.isEmpty) input = 'matrix.org';
    final uri = Uri.tryParse(input.contains('://') ? input : 'https://$input');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Enter a valid Matrix homeserver.');
    }
    if (uri.scheme != 'https' && uri.host != 'localhost') {
      throw const FormatException('Homeservers must use HTTPS.');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    unawaited(client.setForeground(foreground).catchError((_) {}));
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_verificationRequestSubscription?.cancel());
    unawaited(_roomKeyRequestSubscription?.cancel());
    unawaited(_clearVerifications());
    unawaited(_clearRoomKeyRequests());
    unawaited(_linkSubscription?.cancel());
    unawaited(client.close());
    super.dispose();
  }
}

final class MatrixSavedProfile {
  const MatrixSavedProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.homeserver,
    this.avatarUrl,
  });

  factory MatrixSavedProfile.fromJson(Map<String, dynamic> json) =>
      MatrixSavedProfile(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        homeserver: Uri.parse(json['homeserver'] as String),
        avatarUrl: json['avatarUrl'] == null
            ? null
            : Uri.parse(json['avatarUrl'] as String),
      );

  final String id;
  final String userId;
  final String displayName;
  final Uri homeserver;
  final Uri? avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'homeserver': homeserver.toString(),
    'avatarUrl': avatarUrl?.toString(),
  };
}

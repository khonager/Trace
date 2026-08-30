import 'dart:async';

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
  }) : _secureStorage = secureStorage;

  final MatrixClientPort client;
  final FlutterSecureStorage _secureStorage;
  final Map<String, String> _volatileStorage = {};
  StreamSubscription<MatrixClientSnapshot>? _subscription;
  MatrixClientSnapshot _snapshot = const MatrixClientSnapshot.starting();
  bool _busy = false;
  String? _actionError;
  bool _disposed = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  MatrixClientSnapshot get snapshot => _snapshot;
  bool get busy => _busy;
  String? get actionError => _actionError;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _subscription = client.snapshots.listen((snapshot) {
      _snapshot = snapshot;
      if (!_disposed) notifyListeners();
    });
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleLoginCallback,
      onError: (Object error) {
        _actionError = 'Could not read the Matrix sign-in callback.';
        if (!_disposed) notifyListeners();
      },
    );
    await client.initialize();
    _snapshot = client.current;
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) await _handleLoginCallback(initialLink);
    } catch (_) {
      // Deep links are optional on platforms without an app-link handler.
    }
    notifyListeners();
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
    });
  }

  Future<void> logout() => _perform(() async {
    await client.logout();
    await _deleteHint('last_user');
  });

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
    unawaited(_linkSubscription?.cancel());
    unawaited(client.close());
    super.dispose();
  }
}

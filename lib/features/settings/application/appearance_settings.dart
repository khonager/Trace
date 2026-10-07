import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local display preferences. Defaults preserve Trace's original appearance.
class AppearanceSettings extends ChangeNotifier {
  static const _prefix = 'appearance.v1.';
  final Map<String, Object> _pending = {};
  Timer? _writeTimer;
  Future<void> _lastWrite = Future.value();

  double stickerSize = 144;
  double chatPeekWidth = 28;
  bool separateGroups = false;
  bool useProfileBackground = true;
  double backgroundBlur = 48;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    stickerSize = (preferences.getDouble('${_prefix}stickerSize') ?? 144).clamp(
      64.0,
      256.0,
    );
    chatPeekWidth = (preferences.getDouble('${_prefix}chatPeekWidth') ?? 28)
        .clamp(0.0, 72.0);
    separateGroups = preferences.getBool('${_prefix}separateGroups') ?? false;
    useProfileBackground =
        preferences.getBool('${_prefix}useProfileBackground') ?? true;
    backgroundBlur = (preferences.getDouble('${_prefix}backgroundBlur') ?? 48)
        .clamp(0.0, 80.0);
    notifyListeners();
  }

  void setStickerSize(double value) => _setDouble(
    'stickerSize',
    value.clamp(64, 256),
    (value) => stickerSize = value,
  );

  void setChatPeekWidth(double value) => _setDouble(
    'chatPeekWidth',
    value.clamp(0, 72),
    (value) => chatPeekWidth = value,
  );

  void setBackgroundBlur(double value) => _setDouble(
    'backgroundBlur',
    value.clamp(0, 80),
    (value) => backgroundBlur = value,
  );

  void setSeparateGroups(bool value) =>
      _setBool('separateGroups', value, (value) => separateGroups = value);

  void setUseProfileBackground(bool value) => _setBool(
    'useProfileBackground',
    value,
    (value) => useProfileBackground = value,
  );

  Future<void> reset() async {
    stickerSize = 144;
    chatPeekWidth = 28;
    separateGroups = false;
    useProfileBackground = true;
    backgroundBlur = 48;
    notifyListeners();
    _pending.addAll({
      'stickerSize': stickerSize,
      'chatPeekWidth': chatPeekWidth,
      'separateGroups': separateGroups,
      'useProfileBackground': useProfileBackground,
      'backgroundBlur': backgroundBlur,
    });
    await flush();
  }

  void _setDouble(String key, double value, void Function(double) update) {
    update(value);
    notifyListeners();
    _schedule(key, value);
  }

  void _setBool(String key, bool value, void Function(bool) update) {
    update(value);
    notifyListeners();
    _schedule(key, value);
  }

  void _schedule(String key, Object value) {
    _pending[key] = value;
    _writeTimer?.cancel();
    _writeTimer = Timer(const Duration(milliseconds: 160), () {
      unawaited(flush().catchError((Object _) {}));
    });
  }

  /// Saves the latest values after the user finishes dragging a control.
  Future<void> flush() {
    _writeTimer?.cancel();
    _writeTimer = null;
    if (_pending.isEmpty) return _lastWrite;
    final values = Map<String, Object>.of(_pending);
    _pending.clear();
    final write = _lastWrite.catchError((Object _) {}).then((_) async {
      final preferences = await SharedPreferences.getInstance();
      for (final entry in values.entries) {
        switch (entry.value) {
          case final double value:
            await preferences.setDouble('$_prefix${entry.key}', value);
          case final bool value:
            await preferences.setBool('$_prefix${entry.key}', value);
        }
      }
    });
    _lastWrite = write;
    return write;
  }

  @override
  void dispose() {
    unawaited(flush().catchError((Object _) {}));
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceSettings> {
  const AppearanceScope({
    super.key,
    required AppearanceSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppearanceSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

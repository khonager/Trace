import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local display preferences. Defaults preserve Trace's original appearance.
class AppearanceSettings extends ChangeNotifier {
  static const _prefix = 'appearance.v1.';

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

  Future<void> setStickerSize(double value) => _setDouble(
    'stickerSize',
    value.clamp(64, 256),
    (value) => stickerSize = value,
  );

  Future<void> setChatPeekWidth(double value) => _setDouble(
    'chatPeekWidth',
    value.clamp(0, 72),
    (value) => chatPeekWidth = value,
  );

  Future<void> setBackgroundBlur(double value) => _setDouble(
    'backgroundBlur',
    value.clamp(0, 80),
    (value) => backgroundBlur = value,
  );

  Future<void> setSeparateGroups(bool value) =>
      _setBool('separateGroups', value, (value) => separateGroups = value);

  Future<void> setUseProfileBackground(bool value) => _setBool(
    'useProfileBackground',
    value,
    (value) => useProfileBackground = value,
  );

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in [
      'stickerSize',
      'chatPeekWidth',
      'separateGroups',
      'useProfileBackground',
      'backgroundBlur',
    ]) {
      await preferences.remove('$_prefix$key');
    }
    stickerSize = 144;
    chatPeekWidth = 28;
    separateGroups = false;
    useProfileBackground = true;
    backgroundBlur = 48;
    notifyListeners();
  }

  Future<void> _setDouble(
    String key,
    double value,
    void Function(double) update,
  ) async {
    update(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('$_prefix$key', value);
  }

  Future<void> _setBool(
    String key,
    bool value,
    void Function(bool) update,
  ) async {
    update(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_prefix$key', value);
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

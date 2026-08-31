import 'package:shared_preferences/shared_preferences.dart';

enum ComposerAction { attachFile, gifSearch, stickerSearch }

abstract interface class ComposerActionPinStore {
  Future<List<ComposerAction>> load();

  Future<void> save(List<ComposerAction> actions);
}

final class SharedPreferencesComposerActionPinStore
    implements ComposerActionPinStore {
  static const _preferenceKey = 'chat.composer.pinned_actions.v1';

  @override
  Future<List<ComposerAction>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final names = preferences.getStringList(_preferenceKey) ?? const [];
    return names
        .map(
          (name) =>
              ComposerAction.values.where((action) => action.name == name),
        )
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toList(growable: false);
  }

  @override
  Future<void> save(List<ComposerAction> actions) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _preferenceKey,
      actions.map((action) => action.name).toList(growable: false),
    );
  }
}

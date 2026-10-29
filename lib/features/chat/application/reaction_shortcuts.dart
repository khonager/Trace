import 'package:shared_preferences/shared_preferences.dart';

class ReactionShortcuts {
  static const defaults = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '🔥'];
  static const _key = 'chat.reactionShortcuts.v1';

  Future<List<String>> load() async {
    final saved = (await SharedPreferences.getInstance()).getStringList(_key);
    if (saved == null ||
        saved.length != defaults.length ||
        saved.any((value) => value.trim().isEmpty)) {
      return List.of(defaults);
    }
    return List.of(saved);
  }

  Future<void> save(List<String> values) async {
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      _key,
      values,
    );
    if (!saved) throw StateError('Could not save reaction shortcuts');
  }
}

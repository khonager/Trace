import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/features/settings/application/appearance_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'appearance choices persist and Trace defaults can be restored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = AppearanceSettings();
      await first.load();
      expect(first.stickerSize, 144);
      expect(first.chatPeekWidth, 28);
      expect(first.useProfileBackground, isTrue);

      await first.setStickerSize(192);
      await first.setChatPeekWidth(0);
      await first.setSeparateGroups(true);
      await first.setUseProfileBackground(false);
      await first.setBackgroundBlur(12);

      final second = AppearanceSettings();
      await second.load();
      expect(second.stickerSize, 192);
      expect(second.chatPeekWidth, 0);
      expect(second.separateGroups, isTrue);
      expect(second.useProfileBackground, isFalse);
      expect(second.backgroundBlur, 12);

      await second.reset();
      final restored = AppearanceSettings();
      await restored.load();
      expect(restored.stickerSize, 144);
      expect(restored.chatPeekWidth, 28);
      expect(restored.separateGroups, isFalse);
      expect(restored.useProfileBackground, isTrue);
      expect(restored.backgroundBlur, 48);

      first.dispose();
      second.dispose();
      restored.dispose();
    },
  );
}

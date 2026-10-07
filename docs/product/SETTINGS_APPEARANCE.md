# Settings appearance decision

The account card remains first so a profile picture is easy to find. Appearance
controls sit immediately below it and expand in place. A local reset restores
Trace's current look: 144 px stickers, a 28 px chat edge preview, combined chat
list, profile picture backgrounds, and blur 48. This keeps existing users on
the intended visual design while allowing adjustments without server state.

The full selected profile image and its framing values are stored on this
device. Matrix receives a 512 px square crop. Selections above 30 MB are
scaled down with their full aspect ratio before local storage. The stored
source is used only while the Matrix avatar URI still matches, so an avatar
changed by another client cannot be accidentally restored from stale data.

![Expanded appearance settings](settings-appearance.png)

The screenshot is a widget preview. Its test renderer substitutes placeholder
glyphs for Material icons; the controls use the app's Material icons at runtime.

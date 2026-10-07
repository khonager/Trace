# Settings appearance decision

The account card remains first so a profile picture is easy to find. Appearance
controls sit immediately below it and expand in place. A local reset restores
Trace's current look: 144 px stickers, a 28 px chat edge preview, combined chat
list, profile picture backgrounds, and blur 48. This keeps existing users on
the intended visual design while allowing adjustments without server state.

The full selected profile image and its framing values are stored on this
device. Matrix receives a 512 px square render. Selections above 30 MB are
scaled down with their full aspect ratio before local storage. The stored
source is used only while the Matrix avatar URI still matches, so an avatar
changed by another client cannot be accidentally restored from stale data.

Controls repaint as values change; preference writes are grouped after a short
pause in dragging. Edit picture sits beside Replace picture in the profile
dialog, while the display name waits for a deliberate tap. The picture editor
supports drag, pinch zoom, pinch rotation, quarter-turn rotation, flips, and
reset. Circle and Square switch between the avatar crop and the full uploaded
image. Zooming out fills exposed edges with a blurred copy of the source.
The editor preview and Matrix upload use the same painter; the uploaded PNG is
encoded when Save picture is pressed, which commits the profile edit directly.
Older locally stored framing values are converted
when their source image is opened.

![Expanded appearance settings](settings-appearance.png)

![Profile picture editor on a phone](profile-picture-editor-narrow.png)

![Square upload preview on a phone](profile-picture-editor-square.png)

![Profile picture editor at a wide size](profile-picture-editor-wide.png)

These are widget previews. The test renderer substitutes placeholder glyphs for
text and Material icons; the app uses its normal fonts and icons at runtime.

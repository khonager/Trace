# Chat-list navigation

Chats, Calls, and Settings sit at the bottom of the chat list. In the desktop
split view, the conversation and composer retain the full available height.
Collapsing the list also hides its navigation; the chat header can reopen it.
On narrow screens the navigation travels away with the overview when opening a
conversation. Calls and Settings retain bottom navigation to return to Chats.

The navigation remains inside the overview layout, preserving the existing
avatar and swipe geometry instead of resizing the entire workspace mid-gesture.

Reviewed widget renders:

- [Wide split view](chat-navigation-wide.png)
- [Narrow overview](chat-navigation-narrow.png)
- [Expanded conversation](chat-navigation-expanded.png)

Regenerate with `test/app/_capture_chat_layout_test.dart`, `--update-goldens`,
and `--dart-define=CHAT_PREVIEW=wide`, `narrow`, or `expanded`. Set
`TRACE_PREVIEW_FONT` to a local sans-serif TTF for readable preview typography.
The capture helper is skipped unless `TRACE_PREVIEW_FONT` is provided.

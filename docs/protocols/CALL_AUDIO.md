# Caller audio extension

Status: design draft; no event type is registered or implemented.

## Publication

A caller publishes metadata for one active audio excerpt:

- encrypted-content reference;
- SHA-256 content hash;
- duration, encoded size, codec, and normalized loudness;
- monotonically increasing revision;
- optional open-licensed bundled-theme identifier.

The maximum excerpt is 30 seconds. Final codec and byte-size limits remain an
implementation decision.

## Recipient approval

Approval is private recipient state and includes caller Matrix user ID plus the
exact content hash. Changing the content hash returns that caller to the normal
ringtone. Recipients may explicitly trust future changes, require headphones,
exclude callers, or disable the extension globally.

Receiving or caching an excerpt never plays it. Preview requires a user action.
System silent mode, Do Not Disturb, notification permissions, and volume rules
have priority.

## Platform resolution

- Android background: approved custom excerpt, otherwise bundled/default.
- Linux background: approved custom excerpt, otherwise bundled/default.
- iOS foreground: approved custom excerpt is allowed.
- iOS background or locked: CallKit uses a named open-licensed sound included in
  the signed application bundle. Downloaded custom audio is never presented as
  a native CallKit ringtone.

The app must not attempt to manipulate system media volume or start a streaming
service as a ringtone workaround.

# Optional local app and chat locks

App lock is in Settings. Each chat has a lock button in its header. Both are off
by default, independent, and local to this installation. A room lock applies to
that room across local profiles. Each lock can have its own custom credential.

Available methods are device authentication (the system chooses available screen
lock/biometric options), biometrics only, a passcode of one or more digits, any nonempty password, or a 3×3 pattern
of one or more distinct dots. Credential length is chosen by the user. Patterns can
be drawn or entered by tapping/keyboard activation, in order; repeated dots are
ignored. Setup requires confirmation of custom credentials or a successful native
authentication before enabling a device method. Changing or disabling an existing
lock requires its current credential. Custom credentials cannot be recovered.

The native plugin supports Android, iOS, macOS and Windows; Linux and web users
must use custom credentials. Unsupported/unavailable/canceled system prompts
leave the lock closed and show an actionable error. Windows Hello does not offer
biometric-only selection. Android/iOS do not reveal which finger authenticated;
Trace cannot implement finger-specific alternate content or a decoy identity.

## Protection boundary

The app gate is above the navigator and verification overlays. It covers routes
on startup and on loss of foreground focus; protected chats relock as well. If a
protected chat had been unlocked, resuming requires that chat's credential before
revealing any existing media/dialog routes. App and chat credentials remain
independent when both are configured. Unlocks last for the foreground session.
Chat names/avatars remain visible, but protected message previews and message
search results are hidden, even during an unlocked session.

Configuration and salted PBKDF2-HMAC-SHA256 verifiers (600,000 iterations, 128-bit
random salts, 256-bit output) live in platform secure storage. Derivation runs in
a worker isolate on native platforms. Storage read/parse failures block the UI;
write failures preserve the previous configuration. Five failed attempts impose
a 30-second delay. This delay is process-local and resets on restart; the system
provider applies its own biometric lockout rules.

This is a local UI privacy gate, not new encryption of the Matrix database,
attachments, or exports. It does not stop a compromised OS, debugger, modified
client, or someone clearing app storage. It does not revoke files already saved
outside Trace, stop Matrix synchronization, or provide a guarantee against OS
screenshots/task-switcher snapshots. Native biometric enrollment and device PIN
changes are controlled by the OS. Any accepted enrolled biometric can unlock.

## Design and verification

Uses Material dialogs, a lock screen, labeled credential fields, and an accessible
dot grid. Setup is explicit and changes require reauthentication; no biometric
permission prompt appears until the user opts in. Tests cover closed startup,
relocking, chat gates, wrong credentials, persistent configuration, failed
storage, throttling, and stale authentication completion. Native biometric and
app-switcher behavior still require Android/iOS device testing before release.

Lock-screen layout reference: [phone screenshot](../screenshots/app-lock.png).

## Discreet spaces

The ordinary UI has no hidden-chat setting, icon, group list, or hint. Hold
**App lock** in Settings for three seconds to open the neutral Access dialog. **Set up** creates a
space with a name and its own passcode, password, or pattern. This works with
app lock off. A normal tap still opens ordinary app-lock settings. To reopen it, use the same gesture, select the credential type,
and enter that space's credential. Only the matching space opens; other names
and memberships are never listed in this dialog.

After unlocking, select the chats that belong in that space. Done returns to
the app with those chats visible. Close space hides them immediately. App
backgrounding and two minutes without pointer or keyboard activity also close
all spaces. Transient routes (including private images and dialogs) are removed
immediately, without a reverse animation revealing private content. Resuming
shows the ordinary app and does not present a space unlock prompt.

Chat names, avatars, previews, and search results are absent while their space
is closed. Membership and salted credential verifiers live in local secure
storage. An existing individual chat lock is retained and applies again if the
chat leaves its space. Matrix room membership and encryption are unchanged.
These are UI privacy controls, not concealment from someone inspecting app data
with privileged access. Known gestures remain discoverable to someone who
already knows the feature.

The management dialog is shown only after access succeeds. Its phone layout is
captured in [the space controls screenshot](../screenshots/hidden-chats.png).

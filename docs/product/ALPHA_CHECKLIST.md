# Matrix alpha checklist

This checklist separates the shortest path to a usable Matrix client from the
features required before Trace can reasonably be called a full chat alpha.
Calls, AI, live typing, caller audio, subscriptions, and P2P transfer are not
alpha blockers.

## Already in place

- [x] Flutter shell and responsive chat interaction prototype.
- [x] Dart Matrix SDK dependency isolated behind `MatrixClientPort`.
- [x] Vodozemac native cryptography bootstrap.
- [x] Real adapter for login, sync, rooms, encrypted timelines, media, search,
      recovery, and message actions connected to the application shell.
- [x] Persistent Android/Linux SQLite and web IndexedDB stores.
- [x] Nix development environment, unit/widget tests, and reproducible Android,
      Linux, and web builds.

The sample conversations are now used only when `TraceApp` is constructed
without a Matrix session in widget tests. Production composition always injects
the persistent SDK client.

## P0: first usable Matrix alpha

Complete these in order. After this group, a user can log in, restart Trace,
read existing encrypted rooms, and exchange text messages with another Matrix
client or a private self-room.

- [ ] **Encrypted persistent storage**
  - [x] Create the SDK database on Android and Linux, and IndexedDB on web.
  - [x] Initialize, restore, close, migrate, and expire cached media safely.
  - [ ] Add transparent at-rest encryption for SDK account metadata and tokens;
        Matrix event ciphertext alone is not equivalent to an encrypted DB.
  - [x] Keep passwords out of app storage and use OS secure storage for
        non-secret login/SSO hints where the platform provides it.
  - [ ] Store a future database-encryption key in OS secure storage.
- [x] **Login and profile flow**
  - Add a signed-out route before the main shell.
  - Accept `matrix.org`, a Matrix user ID, or a custom homeserver.
  - Discover homeserver capabilities and offered login methods.
  - Implement password login plus browser-based SSO/OIDC callbacks.
  - Show the active account's display name, Matrix ID, avatar, and homeserver.
  - Restore sessions after restart and provide logout/account removal.
- [x] **Application composition and lifecycle**
  - Construct one real Matrix client after storage initialization.
  - Inject it into chat features instead of importing SDK objects in widgets.
  - Handle foreground, background, connectivity loss, token expiry, and clean
        shutdown without creating duplicate sync loops.
- [x] **Real room list and sync**
  - Map joined rooms, invites, names, avatars, unread counts, and last events to
        Trace models.
  - Replace mock conversations with the persistent sync-backed room list.
  - Represent initial loading, offline cache, reconnecting, empty, and error
        states.
- [x] **Real timelines**
  - Load and decrypt cached events for the selected room.
  - Continue incremental sync and insert incoming events without duplicates.
  - Paginate older messages while preserving scroll position.
  - Render sender, timestamp, sending/failed state, and basic system events.
- [ ] **Text sending and receiving**
  - Send the composer body to the selected Matrix room ID.
  - Add optimistic local echo, stable transaction IDs, retry, and failure UI.
  - Reconcile local echoes with server event IDs and prevent double sends.
  - [ ] Verify exchange with a second client and after offline/reconnect cycles.
- [ ] **Encryption safety**
  - [x] Enable and persist encryption state for encrypted rooms.
  - [x] Surface undecryptable events and recovery guidance honestly.
  - [x] Bootstrap cross-signing/key backup and restore with a recovery key or
        passphrase.
  - [ ] Add interactive own-device verification and test recovery on a clean
        second installation.
- [x] **Rooms and people**
  - [x] Search Matrix users and start encrypted direct chats.
  - [x] Accept/decline invites and create encrypted groups or Saved Messages.
  - [x] Join by room address, leave rooms, and distinguish direct/group rooms.
- [x] **Search**
  - [x] Filter rooms and search the homeserver user directory.
  - [x] Search processed events directly in the local Matrix cache.
  - [x] Avoid a separate plaintext search index; results are rebuilt from cache.

## P1: full chat alpha

- [ ] Images, audio messages, and files through normal encrypted Matrix media.
  - [x] Basic encrypted file selection and upload.
  - [ ] Image/audio rendering, recording, upload limits, progress,
        cancellation, download handling, and safe temporary-file cleanup.
- [x] Replies, edits, reactions, redaction/deletion, links, and basic formatted
      messages.
- [x] Typing indicators, drafts, read markers/receipts, mentions, and unread
      notification counts.
- [ ] Android, iOS, and Linux notifications with privacy-safe previews and
      reliable background behavior.
- [ ] Room details: members, topic, avatar, invite permissions, mute settings,
      and basic moderation/report/block controls.
- [ ] Account and device settings.
  - [x] Account profile, device verification status, recovery setup/restore,
        and confirmed logout/local-session removal.
  - [ ] Interactive device verification, session revocation, password changes,
        and account deletion.
- [ ] Accessibility, keyboard navigation, screen-size coverage, localization
      groundwork, and useful loading/empty/error copy.
- [ ] Privacy-safe diagnostics, sanitized logs, crash handling, rate-limit
      handling, and tests against Matrix.org plus a second homeserver.
- [ ] Production application IDs, icons, permissions, signing, license/source
      compliance, and installable Android, iOS, and Linux alpha packages.

## Alpha exit test

The alpha exit test is not yet signed off. It is ready when a clean install can log into Matrix.org or a custom
homeserver, restore that session after restart, show and search real rooms,
decrypt and paginate history, create a private self-room, send and receive text
with correct local-echo/error behavior, recover encryption keys on a second
device, and log out without leaving readable credentials behind.

## Recommended implementation slices

1. Storage, client composition, session restore, and the login/profile route.
2. Real sync-backed room list and timeline mapping.
3. Encrypted text send/receive with local echo and a Saved Messages room.
4. New chat, room/user search, invites, and message search.
5. Encryption recovery, notifications, media, reliability, and packaging.

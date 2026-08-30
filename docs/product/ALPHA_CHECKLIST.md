# Matrix alpha checklist

This checklist separates the shortest path to a usable Matrix client from the
features required before Trace can reasonably be called a full chat alpha.
Calls, AI, live typing, caller audio, subscriptions, and P2P transfer are not
alpha blockers.

## Already in place

- [x] Flutter shell and responsive chat interaction prototype.
- [x] Dart Matrix SDK dependency isolated behind `MatrixClientPort`.
- [x] Vodozemac native cryptography bootstrap.
- [x] Adapter groundwork for homeserver discovery, password login, SSO login
      tokens, sync notifications, logout, and text sending.
- [x] Nix development environment, unit/widget tests, and Linux release build.

The adapter is not connected to the application shell yet. The visible rooms,
timelines, profiles, and sent messages are still mock data.

## P0: first usable Matrix alpha

Complete these in order. After this group, a user can log in, restart Trace,
read existing encrypted rooms, and exchange text messages with another Matrix
client or a private self-room.

- [ ] **Encrypted persistent storage**
  - Create the SDK database on Android, iOS, and Linux.
  - Store its encryption key and Matrix credentials in OS secure storage.
  - Initialize, restore, close, and migrate the database safely.
- [ ] **Login and profile flow**
  - Add a signed-out route before the main shell.
  - Accept `matrix.org`, a Matrix user ID, or a custom homeserver.
  - Discover homeserver capabilities and offered login methods.
  - Implement password login plus browser-based SSO/OIDC callbacks.
  - Show the active account's display name, Matrix ID, avatar, and homeserver.
  - Restore sessions after restart and provide logout/account removal.
- [ ] **Application composition and lifecycle**
  - Construct one real Matrix client after storage initialization.
  - Inject it into chat features instead of importing SDK objects in widgets.
  - Handle foreground, background, connectivity loss, token expiry, and clean
        shutdown without creating duplicate sync loops.
- [ ] **Real room list and sync**
  - Map joined rooms, invites, names, avatars, unread counts, and last events to
        Trace models.
  - Replace mock conversations with the persistent sync-backed room list.
  - Represent initial loading, offline cache, reconnecting, empty, and error
        states.
- [ ] **Real timelines**
  - Load and decrypt cached events for the selected room.
  - Continue incremental sync and insert incoming events without duplicates.
  - Paginate older messages while preserving scroll position.
  - Render sender, timestamp, sending/failed state, and basic system events.
- [ ] **Text sending and receiving**
  - Send the composer body to the selected Matrix room ID.
  - Add optimistic local echo, stable transaction IDs, retry, and failure UI.
  - Reconcile local echoes with server event IDs and prevent double sends.
  - Verify exchange with a second client and after offline/reconnect cycles.
- [ ] **Encryption safety**
  - Enable and persist encryption state for encrypted rooms.
  - Surface undecryptable events and room-key requests honestly.
  - Add own-device verification, cross-signing/bootstrap, and recovery-key or
        key-backup restoration so a new Trace install can read old messages.
- [ ] **Rooms and people**
  - Make the New chat action functional.
  - Search Matrix users, start a direct room, accept/decline invites, and create
        a private room containing only the current user for Saved Messages.
  - Join, leave, and distinguish direct chats from group rooms.
- [ ] **Search**
  - Make the Search action filter rooms and people immediately.
  - Add local message search over decrypted cached events.
  - Keep the local search index encrypted and rebuildable.

## P1: full chat alpha

- [ ] Images, audio messages, and files through normal encrypted Matrix media,
      including upload limits, progress, cancellation, and safe local cleanup.
- [ ] Replies, edits, reactions, redaction/deletion, links, and basic formatted
      messages.
- [ ] Typing indicators, drafts, read markers/receipts, mentions, and unread
      notification counts.
- [ ] Android, iOS, and Linux notifications with privacy-safe previews and
      reliable background behavior.
- [ ] Room details: members, topic, avatar, invite permissions, mute settings,
      and basic moderation/report/block controls.
- [ ] Account and device settings, verification status, session revocation,
      password/recovery guidance, and destructive-action confirmations.
- [ ] Accessibility, keyboard navigation, screen-size coverage, localization
      groundwork, and useful loading/empty/error copy.
- [ ] Privacy-safe diagnostics, sanitized logs, crash handling, rate-limit
      handling, and tests against Matrix.org plus a second homeserver.
- [ ] Production application IDs, icons, permissions, signing, license/source
      compliance, and installable Android, iOS, and Linux alpha packages.

## Alpha exit test

The alpha is ready when a clean install can log into Matrix.org or a custom
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

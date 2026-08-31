# Trace future feature catalog

This is an intentionally broad idea bank, not a committed roadmap. The
checkbox records whether the feature is implemented in Trace today. The badge
records how the feature interoperates.

## Status and interoperability legend

- [x] Implemented in Trace and covered by the current code path.
- [ ] Not implemented, or only a smaller part of the listed feature exists.
- `MATRIX` A stable feature in the current Matrix specification. Its data or
  action can interoperate with other conforming clients.
- `MATRIX+TRACE` Stable Matrix data/API plus substantial Trace-side user
  interface or local behavior.
- `MSC` A Matrix Spec Change proposal or experimental ecosystem convention.
  It may work with some clients, but is not a stable cross-client guarantee.
- `TRACE` Local-only behavior or a Trace-specific event/account-data shape.
  Other Matrix clients will ignore it, show a fallback, or not share the state.
- `EXTERNAL` Requires an operating-system facility, third-party provider,
  integration, bridge, bot, or server deployment outside the core Matrix spec.
- `MATRIX+EXTERNAL` Combines a stable Matrix mechanism with an external
  service, such as an application-service bridge.

“Stable Matrix” does **not** mean every Matrix client has implemented the same
interface. It means the Matrix specification defines an interoperable
representation or API. For example, a GIF sent as `m.image` is standard Matrix
media and other clients can receive it; GIF search needs an external provider;
a confetti effect would be Trace-only unless a future Matrix proposal
standardizes it.

Classification is based on the
[Matrix Client-Server specification](https://spec.matrix.org/latest/client-server-api/)
and the [Matrix specification-change process](https://spec.matrix.org/proposals/).
Re-check `MSC` labels before implementation because proposals can change,
stabilize, or be abandoned.

Implementation audit: 2026-08-31, against Trace `main`. A checked feature means
there is a reachable production code path, not merely SDK support or a
mock-only demonstration. This snapshot marks 74 of 444 individually scoped
items as implemented.

## Text messaging and composition

- [x] `MATRIX` Plain-text messages
- [ ] `TRACE` Multiline composer
- [ ] `MATRIX+TRACE` Markdown formatting
- [ ] `MATRIX+TRACE` Rich-text formatting toolbar
- [ ] `MATRIX+TRACE` Bold, italic, underline, strikethrough, inline code, and code blocks
- [ ] `MATRIX+TRACE` Syntax highlighting and copy buttons for code blocks
- [ ] `MATRIX+TRACE` Block quotes, lists, headings, tables, and spoilers
- [ ] `MATRIX+TRACE` Link detection, previews, and preview suppression
- [x] `TRACE` Drafts saved locally per room for the current app session
- [ ] `MSC` Drafts synchronized between devices (MSC4146)
- [ ] `TRACE` Undo send delay
- [ ] `TRACE` Scheduled messages using an on-device Trace scheduler
- [ ] `TRACE` Send silently without a notification
- [ ] `MSC` Disappearing and view-once messages (MSC2228)
- [ ] `MSC` Message expiry policies per room (MSC1763 family)
- [ ] `MATRIX+TRACE` Copy message text, link, event ID, or formatted content
- [x] `MATRIX` Edit messages
- [ ] `MATRIX+TRACE` View message edit history
- [x] `MATRIX` Delete/redact messages with optional reason
- [ ] `TRACE` Delete locally without redacting for others
- [ ] `MATRIX+TRACE` Forward one or several messages
- [ ] `MATRIX+TRACE` Quote selected text from a message
- [x] `MATRIX` Reply to a specific message
- [x] `MATRIX+TRACE` Reply preview and jump-to-original behavior
- [ ] `MATRIX` Threads and thread-only notification settings
- [ ] `TRACE` Split a discussion into a new thread or room
- [ ] `TRACE` Select and perform bulk actions on messages
- [ ] `TRACE` Message bookmarks and saved-message collections
- [ ] `MATRIX+TRACE` Pin messages within a room
- [ ] `MATRIX+TRACE` Mark messages unread from a chosen point
- [ ] `TRACE` Translation of individual messages or entire rooms
- [ ] `TRACE` Spellcheck, grammar suggestions, and custom dictionary
- [ ] `TRACE` Slash commands and keyboard command palette
- [ ] `TRACE` Templates, snippets, and quick replies
- [ ] `TRACE` Per-room send-on-Enter preference
- [ ] `MATRIX+TRACE` Full emoji, shortcode, and custom-emoji autocomplete
- [ ] `MATRIX+TRACE` `@user`, `@room`, and role mention autocomplete
- [ ] `MATRIX+TRACE` Mention permissions, warnings, and notification previews
- [ ] `TRACE` Hashtags and navigable message labels
- [ ] `TRACE` Read-more collapsing for long messages
- [x] `MATRIX+TRACE` Display message timestamps
- [ ] `TRACE` Compact and detailed timestamp modes
- [x] `MATRIX+TRACE` Sending, failed, sent, and synced message states
- [ ] `MATRIX+TRACE` Per-message read state
- [ ] `MATRIX+TRACE` Read receipts with a viewer list
- [x] `MATRIX+TRACE` Typing indicators
- [ ] `TRACE` Optional live typing previews

## Reactions, GIFs, stickers, and expressive content

- [x] `MATRIX` Send a basic emoji reaction
- [x] `MATRIX` Add and remove arbitrary emoji reactions
- [ ] `MATRIX` Inspect who reacted
- [ ] `MATRIX` Multiple reactions per user
- [ ] `MATRIX` Reaction summary and complete reactor list
- [ ] `MATRIX` Frequently used and recently used reactions
- [ ] `MATRIX` Custom emoji packs
- [ ] `MATRIX` Server, space, and personal emoji packs
- [ ] `MATRIX` Sticker sending and sticker packs
- [ ] `MATRIX` Animated stickers
- [ ] `MATRIX+TRACE` Sticker pack creation, import, export, and moderation
- [ ] `MATRIX` GIF sending from files or URLs
- [ ] `EXTERNAL` Integrated GIF search
- [ ] `TRACE` Favourite and recent GIFs
- [ ] `EXTERNAL` GIF content-safety controls and provider selection
- [ ] `MATRIX+TRACE` Memes, image captions, and simple markup tools
- [ ] `TRACE` Confetti or other optional message effects
- [ ] `TRACE` Large emoji-only rendering
- [ ] `TRACE` Unicode skin-tone and presentation preferences

## Images, files, and documents

- [x] `MATRIX` Attach one file
- [ ] `MATRIX+TRACE` Attach multiple files in one action
- [ ] `MATRIX+TRACE` Drag-and-drop and clipboard paste uploads
- [ ] `MATRIX+TRACE` Upload progress, cancellation, retry, and background transfer
- [x] `MATRIX+TRACE` Download or save received non-image files
- [x] `MATRIX` Upload and download encrypted Matrix attachments
- [ ] `MATRIX+TRACE` Configurable image compression and original-quality sending
- [ ] `MATRIX+TRACE` Photo picker, camera capture, and document scanner
- [x] `MATRIX+TRACE` Render image messages inline
- [ ] `MATRIX+TRACE` Full-screen received-image viewer
- [ ] `MATRIX+TRACE` Zoom, pan, rotate, slideshow, and gallery navigation
- [x] `MATRIX+TRACE` Open received images
- [x] `MATRIX+TRACE` Download or save-as received images
- [ ] `MATRIX+TRACE` Copy received images
- [ ] `MATRIX+TRACE` Share received images
- [ ] `MATRIX+TRACE` Share received media directly to another room or application
- [x] `MATRIX+TRACE` View original filename and file size
- [ ] `MATRIX+TRACE` View MIME type and image dimensions
- [ ] `MATRIX+TRACE` Captions and alt text for images and video
- [ ] `MATRIX+TRACE` Image annotations, cropping, drawing, and redaction
- [ ] `MATRIX+TRACE` View-once images and screenshots policy indicators
- [ ] `MATRIX+TRACE` Animated image playback controls
- [ ] `MATRIX+TRACE` Albums and grouped media messages
- [ ] `MATRIX+TRACE` Room media, links, files, audio, and voice-message browser
- [ ] `MATRIX+TRACE` PDF and common document previews
- [ ] `MATRIX+TRACE` Text, source-code, archive, and office-document previews
- [ ] `MATRIX+TRACE` Open with another installed application
- [ ] `EXTERNAL` Malware scanning and unsafe-file warnings
- [ ] `MATRIX+TRACE` Upload limits and preflight homeserver checks
- [ ] `MATRIX` Transfer over Matrix media
- [ ] `EXTERNAL` Direct peer-to-peer or local-network transfer routes
- [ ] `TRACE` Resumable and chunked uploads/downloads
- [ ] `MATRIX+TRACE` File expiry and automatic downloaded-media cleanup
- [ ] `MATRIX+TRACE` Per-room automatic media download policy
- [ ] `MATRIX+TRACE` Data-saver and Wi-Fi-only transfer modes
- [ ] `MATRIX+TRACE` Accessible descriptions and OCR text extraction

## Audio and voice messages

- [ ] `MATRIX` Record and send voice messages
- [ ] `MATRIX+TRACE` Hold-to-record, slide-to-cancel, and lock-to-record gestures
- [ ] `MATRIX+TRACE` Pause and resume recording
- [ ] `MATRIX+TRACE` Recording preview and trimming
- [ ] `MSC` Voice-message metadata and waveform visualization (MSC3245)
- [ ] `MATRIX+TRACE` Playback speed controls
- [ ] `MATRIX+TRACE` Scrubbing, skip forward/back, and resume position
- [ ] `MATRIX+TRACE` Background and consecutive voice-message playback
- [ ] `MATRIX+TRACE` Earpiece/proximity-sensor playback on phones
- [ ] `MATRIX+TRACE` Noise suppression, echo cancellation, and silence trimming
- [ ] `TRACE` Voice-message captions and local transcription
- [ ] `TRACE` Search voice-message transcripts
- [ ] `MATRIX+TRACE` Audio file player with metadata and album artwork
- [ ] `MATRIX+TRACE` Voice-message forwarding, download, and share

## Video messages and video media

- [ ] `MATRIX+TRACE` Record and send regular videos
- [ ] `MATRIX+TRACE` WhatsApp-style hold-camera circular video messages
- [ ] `MATRIX+TRACE` Switch front/back camera while recording
- [ ] `MATRIX+TRACE` Pause, resume, preview, trim, crop, and mute recordings
- [ ] `MATRIX+TRACE` Video compression and quality selection
- [ ] `MATRIX+TRACE` Inline playback, full-screen playback, and picture-in-picture
- [ ] `MATRIX+TRACE` Playback speed, captions, chapters, and scrubbing
- [ ] `MATRIX+TRACE` Video thumbnails and animated previews
- [ ] `MATRIX+TRACE` Streaming playback before the complete download
- [ ] `MATRIX+TRACE` Download, save, forward, or share received videos
- [ ] `MATRIX+TRACE` View-once video
- [ ] `MATRIX+TRACE` Local video transcription and searchable captions

## Voice and video calling

- [ ] `MATRIX` One-to-one voice calls
- [ ] `MATRIX` One-to-one video calls
- [ ] `MSC` Group voice calls and persistent voice rooms (MatrixRTC/MSC4143)
- [ ] `MSC` Group video conferences (MatrixRTC/MSC4143)
- [ ] `MATRIX+TRACE` Incoming-call screen, ringtone, vibration, and call notifications
- [ ] `EXTERNAL` Call waiting, hold, mute, speaker, Bluetooth, and audio routing
- [ ] `MATRIX+TRACE` Camera switching, camera off, and background blur
- [ ] `MATRIX+TRACE` Virtual backgrounds and portrait framing
- [ ] `MSC` Screen, window, tab, and system-audio sharing through MatrixRTC
- [ ] `EXTERNAL` Remote-control permission during screen sharing
- [ ] `MSC` Raise hand, reactions, polls, and chat during MatrixRTC calls
- [ ] `MATRIX+TRACE` Participant grid, active speaker, and presentation layouts
- [ ] `MATRIX+TRACE` Invite users or rooms into an active call
- [ ] `MSC` Call links, scheduled calls, waiting rooms, and passcodes for MatrixRTC
- [ ] `MATRIX+TRACE` Host, moderator, lobby, and participant permissions
- [ ] `MATRIX+TRACE` End-to-end encrypted calling indicators
- [ ] `MATRIX+TRACE` Network quality, codec, bitrate, and device diagnostics
- [ ] `MATRIX+TRACE` Automatic reconnection and handoff between devices/networks
- [ ] `MATRIX+TRACE` Live captions, transcription, and translation
- [ ] `MATRIX+TRACE` Optional recording with explicit consent and retention controls
- [ ] `MATRIX+TRACE` Call history, missed calls, redial, and call notes
- [ ] `MATRIX+TRACE` Picture-in-picture and background calling
- [ ] `MATRIX+TRACE` Noise cancellation and voice isolation
- [ ] `MATRIX+TRACE` Low-bandwidth audio-only fallback
- [ ] `MATRIX+TRACE` Emergency and abuse-reporting safeguards

## Profiles, identity, and contacts

- [x] `MATRIX+TRACE` Show the active account name, avatar, Matrix ID, and homeserver
- [ ] `MATRIX+TRACE` View another user's room-specific and global profile
- [ ] `MATRIX+TRACE` Profile picture, display name, Matrix ID, pronouns, bio, and status
- [x] `MATRIX+TRACE` View and download full-resolution profile pictures
- [ ] `TRACE` Profile-picture history
- [x] `MATRIX+TRACE` Per-room display names and avatars
- [x] `TRACE` Multiple profiles/accounts with quick switching
- [ ] `MATRIX+TRACE` Custom status, availability, expiry, and status emoji
- [ ] `MATRIX+TRACE` Presence: online, offline, idle, busy, and last active
- [ ] `MATRIX+TRACE` Presence privacy and per-user visibility controls
- [ ] `TRACE` Contact list, favourites, notes, labels, and nicknames
- [ ] `EXTERNAL` Device contacts discovery with privacy-preserving matching
- [ ] `MATRIX+TRACE` QR code, username, link, and nearby contact exchange
- [ ] `MATRIX` Mutual rooms
- [ ] `TRACE` Mutual contacts
- [ ] `MATRIX+TRACE` Trust, verification, shared-server, and encryption information
- [ ] `MATRIX+TRACE` Block, ignore, mute, report, or restrict a user
- [ ] `TRACE` Follow/friend/request model where desired
- [ ] `MATRIX+TRACE` User roles, badges, power level, and moderation history
- [ ] `MATRIX+TRACE` Identity-server configuration and discoverability controls
- [ ] `MATRIX+TRACE` Profile export, account deletion, and data portability

## Rooms, groups, spaces, and communities

- [x] `MATRIX+TRACE` Show joined rooms, invitations, unread counts, and latest-event previews
- [x] `MATRIX+TRACE` Display synchronized room names and avatars
- [x] `MATRIX+TRACE` Direct chats
- [x] `TRACE` Saved Messages
- [x] `MATRIX+TRACE` Private groups
- [x] `MATRIX+TRACE` Public rooms
- [x] `MATRIX+TRACE` Create private rooms
- [x] `MATRIX+TRACE` Join rooms
- [ ] `MATRIX+TRACE` Preview rooms before joining
- [x] `MATRIX+TRACE` Leave rooms
- [ ] `MATRIX+TRACE` Forget rooms
- [ ] `MATRIX+TRACE` Upgrade rooms
- [ ] `MATRIX+TRACE` Archive rooms
- [ ] `MATRIX+TRACE` Invite by Matrix ID, QR code, room alias, contact, or share link
- [x] `MATRIX+TRACE` Accept invitations
- [x] `MATRIX+TRACE` Decline invitations
- [ ] `MSC` Block invitation senders (MSC4380)
- [ ] `MATRIX+TRACE` Report invitations
- [ ] `MATRIX+TRACE` Room name, avatar, topic, description, rules, and welcome screen
- [ ] `MATRIX+TRACE` Member list, roles, permissions, and power-level editor
- [x] `MATRIX+TRACE` Spaces and nested spaces
- [x] `MATRIX+TRACE` Stable administrator-defined ordering inside spaces
- [x] `TRACE` Personal ordering of spaces and navigation shortcuts
- [ ] `MATRIX+TRACE` Suggested rooms and space directory
- [ ] `MATRIX+TRACE` Add/remove/move rooms between spaces
- [ ] `MATRIX+TRACE` Room categories, local folders, and custom user tags
- [x] `MATRIX+TRACE` Rooms belonging to multiple spaces
- [x] `MATRIX+TRACE` Pinned/favourite rooms with manual ordering
- [ ] `MATRIX+TRACE` Low-priority, archived, hidden, and snoozed rooms
- [x] `TRACE` All-chats view
- [ ] `MATRIX+TRACE` Unread view
- [ ] `MATRIX+TRACE` Mentions view
- [ ] `MATRIX+TRACE` Favourites view
- [x] `MATRIX+TRACE` People/direct-chats view
- [x] `MATRIX+TRACE` Spaces views
- [ ] `MATRIX+TRACE` Room aliases, canonical address, and published-room directory
- [ ] `MATRIX+TRACE` Public-room discovery, search, filters, and recommendations
- [ ] `MATRIX+TRACE` Join questions, knock requests, approval, and screening
- [ ] `MATRIX+TRACE` Room templates and cloning
- [ ] `MATRIX+TRACE` Announcement/read-only rooms
- [ ] `TRACE` Forums, topics, and thread-first rooms
- [ ] `TRACE` Event/calendar rooms
- [ ] `TRACE` Broadcast channels and subscriber counts
- [ ] `MATRIX+TRACE` Space-wide roles, announcements, moderation, and search
- [ ] `MATRIX+TRACE` Guest access and room previews
- [ ] `MATRIX+TRACE` Room version upgrades and tombstone migration
- [ ] `MATRIX+TRACE` Room retention, history visibility, and encryption configuration
- [x] `MATRIX+TRACE` Display basic room-name and room-topic system events
- [ ] `MATRIX+TRACE` Duplicate-room and abandoned-room cleanup

## Navigation, ordering, and productivity

- [x] `TRACE` Universal recent-chat inbox
- [x] `MATRIX+TRACE` Pinned-first ordering and manual pin order
- [x] `MATRIX` Stable space/channel ordering
- [x] `TRACE` Drag-reorder spaces
- [ ] `MATRIX+TRACE` Drag-reorder favourite chats
- [ ] `TRACE` Custom sidebar sections and collapsed state
- [ ] `TRACE` Compact, comfortable, and spacious density
- [ ] `TRACE` Keyboard navigation and global shortcuts
- [ ] `TRACE` Quick switcher for rooms, users, spaces, and actions
- [ ] `TRACE` Back/forward navigation history
- [ ] `TRACE` Open chats in split panes, windows, or tabs
- [ ] `TRACE` Recently viewed and frequently used rooms
- [x] `MATRIX+TRACE` Mark the opened room read
- [ ] `MATRIX` Manually mark a room unread or mark all rooms read
- [ ] `TRACE` Catch-up view summarizing unread conversations
- [ ] `TRACE` Inbox-zero archive and snooze workflows
- [ ] `TRACE` Reminders attached to messages
- [ ] `TRACE` To-do extraction, assignments, due dates, and completion
- [ ] `TRACE` Personal notes attached to rooms or contacts
- [ ] `EXTERNAL` Calendar integration and event creation from messages
- [ ] `MATRIX` Deep links to rooms, threads, events, profiles, and media

## Search and discovery

- [x] `TRACE` Search rooms locally by name or cached preview
- [x] `MATRIX` Search the Matrix user directory
- [x] `TRACE` Local full-text message search
- [ ] `MATRIX` Server-side search when available
- [ ] `MATRIX+TRACE` Search within room, thread, space, sender, or date range
- [ ] `MATRIX+TRACE` Filters for text, links, media, files, reactions, and mentions
- [ ] `MATRIX+TRACE` Search users, rooms, spaces, files, and settings from one place
- [ ] `MATRIX+TRACE` Search result highlighting and surrounding context
- [ ] `MATRIX+TRACE` Jump to event and load missing history around it
- [x] `TRACE` Search encrypted content only on trusted local devices
- [ ] `MATRIX+TRACE` OCR, transcript, filename, and attachment-content indexing
- [ ] `MATRIX+TRACE` Search history, saved searches, and search operators
- [ ] `MATRIX+TRACE` Federated room directory and server selection

## Notifications and attention management

- [x] `MATRIX+TRACE` Display synchronized room unread counts
- [ ] `MATRIX+TRACE` Message, mention, reply, reaction, invite, and call notifications
- [ ] `MATRIX+TRACE` Per-room all-message, mentions-only, or mute settings
- [ ] `MATRIX+TRACE` Per-thread notification settings
- [ ] `MATRIX+TRACE` Keyword and user-specific notification rules
- [ ] `MATRIX+TRACE` Space-wide notification defaults
- [ ] `MATRIX+TRACE` Temporary mute and snooze-until controls
- [ ] `MATRIX+TRACE` Quiet hours, schedules, focus modes, and time-zone support
- [ ] `MATRIX+TRACE` Notification grouping and inline reply/actions
- [ ] `MATRIX+TRACE` Privacy-safe notification previews
- [ ] `MATRIX+TRACE` Sound, vibration, badge, and LED controls
- [ ] `MATRIX+TRACE` Cross-device notification dismissal
- [ ] `MATRIX+TRACE` Notification history and missed-activity inbox
- [ ] `MATRIX+TRACE` Smart bundling without server-side content exposure
- [ ] `MATRIX+TRACE` Calls bypassing mute only for selected contacts

## Polls, events, location, and structured messages

- [ ] `MSC` Single-choice and multiple-choice polls (MSC3381)
- [ ] `MSC` Anonymous, public, open, and closed polls (MSC3381)
- [ ] `MSC` Poll editing, expiry, results, and reminders (MSC3381)
- [ ] `MSC` Calendar events, invitations, RSVP, and reminders (MSC4496)
- [ ] `MATRIX` Location pins and map previews
- [ ] `MSC` Live location sharing with expiry and precision controls (MSC3672)
- [ ] `TRACE` Contact cards
- [ ] `TRACE` Tasks, checklists, assignments, and approvals
- [ ] `TRACE` Forms, surveys, and structured data cards
- [ ] `EXTERNAL` Payments, invoices, and payment-request cards where appropriate
- [ ] `TRACE` Product, music, article, repository, and issue previews
- [ ] `EXTERNAL` Collaborative documents, whiteboards, and canvases

## Encryption, verification, privacy, and security

- [x] `MATRIX` End-to-end encryption by default
- [x] `MATRIX` Cross-signing and emoji/number device verification
- [ ] `MATRIX` QR device verification
- [x] `MATRIX` Recovery key, passphrase, secret storage, and key backup
- [x] `MATRIX` Request missing room keys and show recovery guidance
- [ ] `MATRIX+TRACE` Automatically retry every eligible missing-key request
- [x] `MATRIX+TRACE` Surface undecryptable messages and recovery guidance
- [ ] `MATRIX+TRACE` Detailed per-message encryption/decryption diagnostics
- [x] `MATRIX` Device/session list and verification state
- [ ] `MATRIX+TRACE` Name devices/sessions
- [ ] `MATRIX+TRACE` Revoke other sessions
- [ ] `MATRIX+TRACE` Login/session history and suspicious-login alerts
- [ ] `TRACE` App lock with biometrics, PIN, or system credentials
- [ ] `TRACE` Screen security, screenshot policy, and recent-app blur
- [x] `TRACE` Local persistent database and attachment cache
- [ ] `TRACE` Encrypt the local database and attachment cache at rest
- [ ] `TRACE` Configurable cache retention and secure deletion
- [ ] `TRACE` Privacy dashboard and permission history
- [ ] `TRACE` Link tracking-parameter removal and safe browsing
- [ ] `EXTERNAL` Proxy, VPN, Tor, and custom DNS support
- [ ] `TRACE` Certificate pinning options and custom CA certificates
- [ ] `MATRIX+TRACE` Metadata-minimizing presence, receipts, and typing controls
- [ ] `TRACE` Incognito rooms with reduced local persistence
- [ ] `MATRIX+TRACE` Panic lock/logout and remote session revocation
- [ ] `MATRIX+TRACE` Security key/passkey authentication where supported
- [ ] `MATRIX+TRACE` Transparency logs or warnings for identity-key changes
- [ ] `TRACE` Exportable security diagnostics with secrets removed

## Moderation, safety, and abuse prevention

- [ ] `MATRIX` Report message, media, room, space, or user
- [ ] `MATRIX` Block/ignore lists synchronized through Matrix
- [ ] `MATRIX+TRACE` Kick, ban, unban, mute, redact, and deactivate controls
- [ ] `MATRIX+TRACE` Moderation reasons, evidence links, and audit log
- [ ] `MATRIX+TRACE` Moderator queues and report assignment
- [ ] `MATRIX+TRACE` Spam, flood, invite, mention, and upload rate limits
- [ ] `MATRIX+TRACE` Join rules, knock approval, CAPTCHA, and invite codes
- [ ] `MATRIX+TRACE` Content warnings, sensitive-media blur, and age gates
- [ ] `MATRIX+TRACE` Keyword, URL, MIME-type, and file-size moderation rules
- [ ] `MATRIX` Community moderation lists and policy rooms
- [ ] `MATRIX+TRACE` Raid mode and emergency room lockdown
- [ ] `MATRIX+TRACE` New-account and unverified-device restrictions
- [ ] `MATRIX+TRACE` Per-room ignored-user placeholders
- [ ] `MATRIX+TRACE` Safety center, help resources, and guardian controls
- [ ] `MATRIX+TRACE` Appeals and transparent enforcement records

## Offline use, sync, and reliability

- [x] `TRACE` Full offline reading of cached rooms and media
- [x] `MATRIX+TRACE` Paginate older room history
- [x] `MATRIX+TRACE` Retry a failed outgoing message
- [ ] `TRACE` Offline send queue with retry/cancel
- [x] `TRACE` Optimistic messages with robust transaction IDs
- [ ] `TRACE` Background sync
- [ ] `MATRIX+TRACE` Push notifications
- [ ] `MSC` Simplified Sliding Sync support (MSC4186)
- [ ] `MATRIX+TRACE` Selective room, history, and media synchronization
- [x] `TRACE` Sync progress and first-login status
- [x] `TRACE` Network-aware reconnect and exponential backoff
- [ ] `TRACE` Conflict handling for edits, drafts, pins, and preferences
- [ ] `TRACE` Message deduplication and ordering correction
- [ ] `TRACE` Low-data, low-memory, and battery-saver modes
- [ ] `TRACE` Cache repair and corruption recovery
- [x] `TRACE` Database migrations
- [ ] `TRACE` Backup/restore of local preferences
- [x] `MATRIX+TRACE` Restore Matrix sessions after an app restart
- [ ] `TRACE` Multi-device state reconciliation
- [ ] `TRACE` Diagnostics for homeserver, federation, media, and crypto failures

## Accessibility and internationalization

- [ ] `TRACE` Complete screen-reader labels, order, and live regions
- [ ] `TRACE` Keyboard-only operation and visible focus states
- [ ] `TRACE` Dynamic type and large-text layouts
- [ ] `TRACE` High contrast, reduced motion, and reduced transparency
- [ ] `TRACE` Colour-blind-safe status indicators
- [ ] `TRACE` Do not rely on colour alone for delivery or trust state
- [ ] `TRACE` Captions, transcripts, and audio descriptions
- [ ] `TRACE` Alt-text authoring and missing-alt-text prompts
- [ ] `TRACE` Right-to-left layouts and bidirectional text handling
- [ ] `TRACE` Full localization, pluralization, and locale-aware formatting
- [ ] `TRACE` Per-message language detection and translation controls
- [ ] `TRACE` Dyslexia-friendly font and reading modes
- [ ] `TRACE` Haptic alternatives and configurable gesture timing
- [ ] `TRACE` Accessible emoji, sticker, GIF, and reaction descriptions

## Appearance and personalization

- [ ] `TRACE` Light, dark, system, and scheduled themes
- [ ] `TRACE` Custom accent colours and theme packs
- [ ] `TRACE` Per-room wallpapers and background blur controls
- [ ] `TRACE` Font family, size, line height, and message width settings
- [ ] `TRACE` Bubble, compact, IRC, forum, and accessibility layouts
- [ ] `TRACE` Avatar shape and animation preferences
- [ ] `TRACE` Hide avatars, previews, timestamps, or reactions
- [ ] `TRACE` Custom app icon and notification icon
- [ ] `TRACE` Reduced animations and media autoplay settings
- [ ] `TRACE` Per-account appearance profiles
- [ ] `TRACE` Import/export theme settings

## Bots, integrations, widgets, and automation

- [ ] `MATRIX` Bots and application services
- [ ] `EXTERNAL` Webhooks for incoming and outgoing events
- [ ] `EXTERNAL` Room widgets and embedded applications through the Matrix Widget API
- [ ] `EXTERNAL` GitHub, GitLab, Linear, Jira, calendar, and CI integrations
- [ ] `EXTERNAL` Email and RSS bridges
- [ ] `MATRIX+EXTERNAL` IRC, Slack, Discord, Telegram, and other bridges
- [ ] `EXTERNAL` Music, video, map, document, and whiteboard widgets
- [ ] `EXTERNAL` User-defined rules and no-code automations
- [ ] `EXTERNAL` Scheduled jobs and recurring messages
- [ ] `EXTERNAL` Moderation and welcome bots
- [ ] `EXTERNAL` Bot permission and data-access review
- [ ] `EXTERNAL` Integration directory, install, update, disable, and audit flows
- [ ] `EXTERNAL` Webhook secret rotation and delivery logs

## Optional local AI features

- [ ] `TRACE` Local-only unread summaries
- [ ] `TRACE` Local semantic search and related-message discovery
- [ ] `TRACE` Draft rewriting, tone, spelling, and translation assistance
- [ ] `TRACE` Voice transcription and meeting notes
- [ ] `TRACE` Action-item and date extraction
- [ ] `TRACE` Thread titles and room catch-up summaries
- [ ] `TRACE` Image description and OCR assistance
- [ ] `EXTERNAL` User-controlled model/provider selection
- [ ] `TRACE` Clear disclosure of data leaving the device
- [ ] `TRACE` Per-room AI disable controls
- [ ] `TRACE` No training, retention, or background upload by default
- [ ] `TRACE` Review-before-send for every generated message

## Platform and operating-system integration

- [x] `TRACE` Android, Linux, and web support
- [ ] `TRACE` iOS support
- [ ] `TRACE` Windows support
- [ ] `TRACE` macOS support
- [ ] `TRACE` Native share target and share sheet
- [x] `TRACE` Save-to-files integration
- [ ] `TRACE` Open-with integration
- [ ] `EXTERNAL` Camera, microphone, contacts, photos, location, and Bluetooth permissions
- [ ] `TRACE` Home-screen widgets and app shortcuts
- [ ] `TRACE` Notification quick reply and call actions
- [ ] `TRACE` Deep/universal links and verified app links
- [ ] `TRACE` Picture-in-picture and media controls
- [ ] `TRACE` System tray/menu bar and unread badge
- [ ] `TRACE` Multi-window, desktop drag-and-drop, and global shortcuts
- [ ] `TRACE` Background launch, startup, and battery optimization guidance
- [ ] `TRACE` Wear OS, watchOS, Android Auto, and CarPlay companion experiences
- [ ] `TRACE` Backup exclusion and secure platform keystore integration
- [ ] `TRACE` Installer, auto-update, release channels, and rollback

## Import, export, backup, and portability

- [ ] `TRACE` Export messages and media in human-readable formats
- [ ] `TRACE` Encrypted archive export and import
- [ ] `TRACE` Export a room, thread, date range, or personal data only
- [ ] `TRACE` Account-data, settings, pins, and space-order portability
- [ ] `TRACE` Migration from other Matrix clients
- [ ] `TRACE` Migration/import from other messaging services where lawful
- [ ] `TRACE` GDPR-style data download and deletion assistance
- [ ] `TRACE` Media archive with checksums and original filenames
- [ ] `TRACE` Print and PDF conversation export
- [ ] `TRACE` Backup verification and restore preview

## Administration and deployment

- [x] `MATRIX` Homeserver discovery
- [ ] `MATRIX+TRACE` Homeserver compatibility and health diagnostics
- [x] `MATRIX+TRACE` Custom homeserver selection
- [ ] `MATRIX+TRACE` Custom identity server, push gateway, and TURN settings
- [ ] `EXTERNAL` Managed configuration and enterprise policy
- [x] `MATRIX` Password login
- [x] `MATRIX` Legacy browser SSO login
- [x] `MATRIX+TRACE` Sign out and remove the selected local session
- [ ] `MATRIX` Native Matrix OAuth/OIDC login
- [ ] `EXTERNAL` SAML and LDAP through a homeserver
- [ ] `MATRIX+EXTERNAL` Passkey login where supported
- [ ] `EXTERNAL` Multi-tenant branding and configuration
- [ ] `EXTERNAL` Feature flags and staged rollout
- [ ] `EXTERNAL` Crash reporting and privacy-respecting telemetry opt-in
- [ ] `EXTERNAL` Performance, sync, media, and call observability
- [ ] `EXTERNAL` Remote configuration with signed policy
- [ ] `EXTERNAL` Data residency and retention controls
- [ ] `EXTERNAL` Admin console links and support bundles
- [ ] `TRACE` Reproducible builds, dependency audit, and software bill of materials
- [ ] `TRACE` Accessibility, security, privacy, and interoperability test suites

## Possible prioritization questions

For every selected feature, decide:

- Does an existing stable Matrix event/API represent it?
- Does it synchronize across devices and interoperate with other clients?
- Is it personal account data, shared room state, or local-only state?
- What happens in encrypted rooms and on unverified devices?
- What metadata is visible to the homeserver, integration, or third party?
- What is the offline, retry, failure, and migration behavior?
- Which platforms support it, and what is the accessible alternative?
- Who is allowed to use or configure it?
- What abuse, consent, retention, and reporting controls are required?
- What is the smallest useful version, and what can be added later?

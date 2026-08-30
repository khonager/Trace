# Trace future feature catalog

This is an intentionally broad idea bank, not a committed roadmap. Items can
be copied into milestones after deciding their value, privacy impact, Matrix
interoperability, platform support, and implementation cost.

Suggested labels when selecting an item: `must`, `should`, `could`, `wont-now`,
plus `local-only`, `Matrix-standard`, `custom-protocol`, and `needs-server`.

## Text messaging and composition

- [ ] Plain-text messages
- [ ] Multiline composer
- [ ] Markdown formatting
- [ ] Rich-text formatting toolbar
- [ ] Bold, italic, underline, strikethrough, inline code, and code blocks
- [ ] Syntax highlighting and copy buttons for code blocks
- [ ] Block quotes, lists, headings, tables, and spoilers
- [ ] Link detection, previews, and preview suppression
- [ ] Drafts saved per room and synchronized between devices
- [ ] Undo send delay
- [ ] Scheduled messages
- [ ] Send silently without a notification
- [ ] Disappearing and view-once messages
- [ ] Message expiry policies per room
- [ ] Copy message text, link, event ID, or formatted content
- [ ] Edit messages with edit history
- [ ] Delete/redact messages with optional reason
- [ ] Delete locally without redacting for others
- [ ] Forward one or several messages
- [ ] Quote selected text from a message
- [ ] Reply to a specific message
- [ ] Reply preview and jump-to-original behavior
- [ ] Threads and thread-only notification settings
- [ ] Split a discussion into a new thread or room
- [ ] Select and perform bulk actions on messages
- [ ] Message bookmarks and saved-message collections
- [ ] Pin messages within a room
- [ ] Mark messages unread from a chosen point
- [ ] Translation of individual messages or entire rooms
- [ ] Spellcheck, grammar suggestions, and custom dictionary
- [ ] Slash commands and keyboard command palette
- [ ] Templates, snippets, and quick replies
- [ ] Per-room send-on-Enter preference
- [ ] Full emoji, shortcode, and custom-emoji autocomplete
- [ ] `@user`, `@room`, and role mention autocomplete
- [ ] Mention permissions, warnings, and notification previews
- [ ] Hashtags and navigable message labels
- [ ] Read-more collapsing for long messages
- [ ] Message timestamps with compact and detailed modes
- [ ] Per-message delivery, sent, synced, read, and failed states
- [ ] Read receipts with a viewer list
- [ ] Typing indicators and optional live typing previews

## Reactions, GIFs, stickers, and expressive content

- [ ] Add, remove, and inspect emoji reactions
- [ ] Multiple reactions per user
- [ ] Reaction summary and complete reactor list
- [ ] Frequently used and recently used reactions
- [ ] Custom emoji packs
- [ ] Server, space, and personal emoji packs
- [ ] Sticker sending and sticker packs
- [ ] Animated stickers
- [ ] Sticker pack creation, import, export, and moderation
- [ ] GIF sending from files or URLs
- [ ] Integrated GIF search
- [ ] Favourite and recent GIFs
- [ ] GIF content-safety controls and provider selection
- [ ] Memes, image captions, and simple markup tools
- [ ] Confetti or other optional message effects
- [ ] Large emoji-only rendering
- [ ] Unicode skin-tone and presentation preferences

## Images, files, and documents

- [ ] Attach one or multiple files
- [ ] Drag-and-drop and clipboard paste uploads
- [ ] Upload progress, cancellation, retry, and background transfer
- [ ] Configurable image compression and original-quality sending
- [ ] Photo picker, camera capture, and document scanner
- [ ] Image thumbnails and full-screen viewer
- [ ] Zoom, pan, rotate, slideshow, and gallery navigation
- [ ] Open, download, save-as, copy, or share received images
- [ ] Share received media directly to another room or application
- [ ] View original filename, MIME type, dimensions, and file size
- [ ] Captions and alt text for images and video
- [ ] Image annotations, cropping, drawing, and redaction
- [ ] View-once images and screenshots policy indicators
- [ ] Animated image playback controls
- [ ] Albums and grouped media messages
- [ ] Room media, links, files, audio, and voice-message browser
- [ ] PDF and common document previews
- [ ] Text, source-code, archive, and office-document previews
- [ ] Open with another installed application
- [ ] Malware scanning and unsafe-file warnings
- [ ] Upload limits and preflight homeserver checks
- [ ] Transfer over Matrix media, direct peer-to-peer, or local-network routes
- [ ] Resumable and chunked uploads/downloads
- [ ] File expiry and automatic downloaded-media cleanup
- [ ] Per-room automatic media download policy
- [ ] Data-saver and Wi-Fi-only transfer modes
- [ ] Accessible descriptions and OCR text extraction

## Audio and voice messages

- [ ] Record and send voice messages
- [ ] Hold-to-record, slide-to-cancel, and lock-to-record gestures
- [ ] Pause and resume recording
- [ ] Recording preview and trimming
- [ ] Waveform visualization
- [ ] Playback speed controls
- [ ] Scrubbing, skip forward/back, and resume position
- [ ] Background and consecutive voice-message playback
- [ ] Earpiece/proximity-sensor playback on phones
- [ ] Noise suppression, echo cancellation, and silence trimming
- [ ] Voice-message captions and local transcription
- [ ] Search voice-message transcripts
- [ ] Audio file player with metadata and album artwork
- [ ] Voice-message forwarding, download, and share

## Video messages and video media

- [ ] Record and send regular videos
- [ ] WhatsApp-style hold-camera circular video messages
- [ ] Switch front/back camera while recording
- [ ] Pause, resume, preview, trim, crop, and mute recordings
- [ ] Video compression and quality selection
- [ ] Inline playback, full-screen playback, and picture-in-picture
- [ ] Playback speed, captions, chapters, and scrubbing
- [ ] Video thumbnails and animated previews
- [ ] Streaming playback before the complete download
- [ ] Download, save, forward, or share received videos
- [ ] View-once video
- [ ] Local video transcription and searchable captions

## Voice and video calling

- [ ] One-to-one voice calls
- [ ] One-to-one video calls
- [ ] Group voice calls and persistent voice rooms
- [ ] Group video conferences
- [ ] Incoming-call screen, ringtone, vibration, and call notifications
- [ ] Call waiting, hold, mute, speaker, Bluetooth, and audio routing
- [ ] Camera switching, camera off, and background blur
- [ ] Virtual backgrounds and portrait framing
- [ ] Screen, window, tab, and system-audio sharing
- [ ] Remote-control permission during screen sharing
- [ ] Raise hand, reactions, polls, and chat during calls
- [ ] Participant grid, active speaker, and presentation layouts
- [ ] Invite users or rooms into an active call
- [ ] Call links, scheduled calls, waiting rooms, and passcodes
- [ ] Host, moderator, lobby, and participant permissions
- [ ] End-to-end encrypted calling indicators
- [ ] Network quality, codec, bitrate, and device diagnostics
- [ ] Automatic reconnection and handoff between devices/networks
- [ ] Live captions, transcription, and translation
- [ ] Optional recording with explicit consent and retention controls
- [ ] Call history, missed calls, redial, and call notes
- [ ] Picture-in-picture and background calling
- [ ] Noise cancellation and voice isolation
- [ ] Low-bandwidth audio-only fallback
- [ ] Emergency and abuse-reporting safeguards

## Profiles, identity, and contacts

- [ ] View another user's room-specific and global profile
- [ ] Profile picture, display name, Matrix ID, pronouns, bio, and status
- [ ] Profile-picture history and full-screen viewer
- [ ] Per-room display names and avatars
- [ ] Multiple profiles/accounts with quick switching
- [ ] Custom status, availability, expiry, and status emoji
- [ ] Presence: online, offline, idle, busy, and last active
- [ ] Presence privacy and per-user visibility controls
- [ ] Contact list, favourites, notes, labels, and nicknames
- [ ] Device contacts discovery with privacy-preserving matching
- [ ] QR code, username, link, and nearby contact exchange
- [ ] Mutual rooms and mutual contacts
- [ ] Trust, verification, shared-server, and encryption information
- [ ] Block, ignore, mute, report, or restrict a user
- [ ] Follow/friend/request model where desired
- [ ] User roles, badges, power level, and moderation history
- [ ] Identity-server configuration and discoverability controls
- [ ] Profile export, account deletion, and data portability

## Rooms, groups, spaces, and communities

- [ ] Direct chats, Saved Messages, private groups, and public rooms
- [ ] Create, join, preview, leave, forget, upgrade, and archive rooms
- [ ] Invite by Matrix ID, QR code, room alias, contact, or share link
- [ ] Accept, reject, block, or report invitations
- [ ] Room name, avatar, topic, description, rules, and welcome screen
- [ ] Member list, roles, permissions, and power-level editor
- [ ] Spaces and nested spaces
- [ ] Stable administrator-defined ordering inside spaces
- [ ] Personal ordering of spaces and navigation shortcuts
- [ ] Suggested rooms and space directory
- [ ] Add/remove/move rooms between spaces
- [ ] Room categories, local folders, and custom user tags
- [ ] Rooms belonging to multiple spaces
- [ ] Pinned/favourite rooms with manual ordering
- [ ] Low-priority, archived, hidden, and snoozed rooms
- [ ] All-chats, unread, mentions, favourites, people, and spaces views
- [ ] Room aliases, canonical address, and published-room directory
- [ ] Public-room discovery, search, filters, and recommendations
- [ ] Join questions, knock requests, approval, and screening
- [ ] Room templates and cloning
- [ ] Announcement/read-only rooms
- [ ] Forums, topics, and thread-first rooms
- [ ] Event/calendar rooms
- [ ] Broadcast channels and subscriber counts
- [ ] Space-wide roles, announcements, moderation, and search
- [ ] Guest access and room previews
- [ ] Room version upgrades and tombstone migration
- [ ] Room retention, history visibility, and encryption configuration
- [ ] Duplicate-room and abandoned-room cleanup

## Navigation, ordering, and productivity

- [ ] Universal recent-chat inbox
- [ ] Pinned-first ordering and manual pin order
- [ ] Stable space/channel ordering
- [ ] Drag-reorder spaces and favourites
- [ ] Custom sidebar sections and collapsed state
- [ ] Compact, comfortable, and spacious density
- [ ] Keyboard navigation and global shortcuts
- [ ] Quick switcher for rooms, users, spaces, and actions
- [ ] Back/forward navigation history
- [ ] Open chats in split panes, windows, or tabs
- [ ] Recently viewed and frequently used rooms
- [ ] Mark room read/unread and mark all read
- [ ] Catch-up view summarizing unread conversations
- [ ] Inbox-zero archive and snooze workflows
- [ ] Reminders attached to messages
- [ ] To-do extraction, assignments, due dates, and completion
- [ ] Personal notes attached to rooms or contacts
- [ ] Calendar integration and event creation from messages
- [ ] Deep links to rooms, threads, events, profiles, and media

## Search and discovery

- [ ] Local full-text message search
- [ ] Server-side search when available
- [ ] Search within room, thread, space, sender, or date range
- [ ] Filters for text, links, media, files, reactions, and mentions
- [ ] Search users, rooms, spaces, files, and settings from one place
- [ ] Search result highlighting and surrounding context
- [ ] Jump to event and load missing history around it
- [ ] Search encrypted content only on trusted local devices
- [ ] OCR, transcript, filename, and attachment-content indexing
- [ ] Search history, saved searches, and search operators
- [ ] Federated room directory and server selection

## Notifications and attention management

- [ ] Message, mention, reply, reaction, invite, and call notifications
- [ ] Per-room all-message, mentions-only, or mute settings
- [ ] Per-thread notification settings
- [ ] Keyword and user-specific notification rules
- [ ] Space-wide notification defaults
- [ ] Temporary mute and snooze-until controls
- [ ] Quiet hours, schedules, focus modes, and time-zone support
- [ ] Notification grouping and inline reply/actions
- [ ] Privacy-safe notification previews
- [ ] Sound, vibration, badge, and LED controls
- [ ] Cross-device notification dismissal
- [ ] Notification history and missed-activity inbox
- [ ] Smart bundling without server-side content exposure
- [ ] Calls bypassing mute only for selected contacts

## Polls, events, location, and structured messages

- [ ] Single-choice and multiple-choice polls
- [ ] Anonymous, public, open, and closed polls
- [ ] Poll editing, expiry, results, and reminders
- [ ] Calendar events, invitations, RSVP, and reminders
- [ ] Location pins and map previews
- [ ] Live location sharing with expiry and precision controls
- [ ] Contact cards
- [ ] Tasks, checklists, assignments, and approvals
- [ ] Forms, surveys, and structured data cards
- [ ] Payments, invoices, and payment-request cards where appropriate
- [ ] Product, music, article, repository, and issue previews
- [ ] Collaborative documents, whiteboards, and canvases

## Encryption, verification, privacy, and security

- [ ] End-to-end encryption by default
- [ ] Cross-signing and emoji/QR/device verification
- [ ] Recovery key, passphrase, secret storage, and key backup
- [ ] Automatic missing-key requests and recovery guidance
- [ ] Per-message encryption/decryption diagnostics
- [ ] Device/session list, naming, verification, and revocation
- [ ] Login/session history and suspicious-login alerts
- [ ] App lock with biometrics, PIN, or system credentials
- [ ] Screen security, screenshot policy, and recent-app blur
- [ ] Local encrypted database and attachment cache
- [ ] Configurable cache retention and secure deletion
- [ ] Privacy dashboard and permission history
- [ ] Link tracking-parameter removal and safe browsing
- [ ] Proxy, VPN, Tor, and custom DNS support
- [ ] Certificate pinning options and custom CA certificates
- [ ] Metadata-minimizing presence, receipts, and typing controls
- [ ] Incognito rooms with reduced local persistence
- [ ] Panic lock/logout and remote session revocation
- [ ] Security key/passkey authentication where supported
- [ ] Transparency logs or warnings for identity-key changes
- [ ] Exportable security diagnostics with secrets removed

## Moderation, safety, and abuse prevention

- [ ] Report message, media, room, space, or user
- [ ] Block/ignore lists synchronized through Matrix
- [ ] Kick, ban, unban, mute, redact, and deactivate controls
- [ ] Moderation reasons, evidence links, and audit log
- [ ] Moderator queues and report assignment
- [ ] Spam, flood, invite, mention, and upload rate limits
- [ ] Join rules, knock approval, CAPTCHA, and invite codes
- [ ] Content warnings, sensitive-media blur, and age gates
- [ ] Keyword, URL, MIME-type, and file-size moderation rules
- [ ] Community moderation lists and policy rooms
- [ ] Raid mode and emergency room lockdown
- [ ] New-account and unverified-device restrictions
- [ ] Per-room ignored-user placeholders
- [ ] Safety center, help resources, and guardian controls
- [ ] Appeals and transparent enforcement records

## Offline use, sync, and reliability

- [ ] Full offline reading of cached rooms and media
- [ ] Offline send queue with retry/cancel
- [ ] Optimistic messages with robust transaction IDs
- [ ] Background sync and push notifications
- [ ] Sliding Sync support
- [ ] Selective room, history, and media synchronization
- [ ] Sync progress and first-login status
- [ ] Network-aware reconnect and exponential backoff
- [ ] Conflict handling for edits, drafts, pins, and preferences
- [ ] Message deduplication and ordering correction
- [ ] Low-data, low-memory, and battery-saver modes
- [ ] Cache repair, database migrations, and corruption recovery
- [ ] Backup/restore of local preferences
- [ ] Multi-device state reconciliation
- [ ] Diagnostics for homeserver, federation, media, and crypto failures

## Accessibility and internationalization

- [ ] Complete screen-reader labels, order, and live regions
- [ ] Keyboard-only operation and visible focus states
- [ ] Dynamic type and large-text layouts
- [ ] High contrast, reduced motion, and reduced transparency
- [ ] Colour-blind-safe status indicators
- [ ] Do not rely on colour alone for delivery or trust state
- [ ] Captions, transcripts, and audio descriptions
- [ ] Alt-text authoring and missing-alt-text prompts
- [ ] Right-to-left layouts and bidirectional text handling
- [ ] Full localization, pluralization, and locale-aware formatting
- [ ] Per-message language detection and translation controls
- [ ] Dyslexia-friendly font and reading modes
- [ ] Haptic alternatives and configurable gesture timing
- [ ] Accessible emoji, sticker, GIF, and reaction descriptions

## Appearance and personalization

- [ ] Light, dark, system, and scheduled themes
- [ ] Custom accent colours and theme packs
- [ ] Per-room wallpapers and background blur controls
- [ ] Font family, size, line height, and message width settings
- [ ] Bubble, compact, IRC, forum, and accessibility layouts
- [ ] Avatar shape and animation preferences
- [ ] Hide avatars, previews, timestamps, or reactions
- [ ] Custom app icon and notification icon
- [ ] Reduced animations and media autoplay settings
- [ ] Per-account appearance profiles
- [ ] Import/export theme settings

## Bots, integrations, widgets, and automation

- [ ] Bots and application services
- [ ] Webhooks for incoming and outgoing events
- [ ] Room widgets and embedded applications
- [ ] GitHub, GitLab, Linear, Jira, calendar, and CI integrations
- [ ] Email and RSS bridges
- [ ] IRC, Slack, Discord, Telegram, and other bridges
- [ ] Music, video, map, document, and whiteboard widgets
- [ ] User-defined rules and no-code automations
- [ ] Scheduled jobs and recurring messages
- [ ] Moderation and welcome bots
- [ ] Bot permission and data-access review
- [ ] Integration directory, install, update, disable, and audit flows
- [ ] Webhook secret rotation and delivery logs

## Optional local AI features

- [ ] Local-only unread summaries
- [ ] Local semantic search and related-message discovery
- [ ] Draft rewriting, tone, spelling, and translation assistance
- [ ] Voice transcription and meeting notes
- [ ] Action-item and date extraction
- [ ] Thread titles and room catch-up summaries
- [ ] Image description and OCR assistance
- [ ] User-controlled model/provider selection
- [ ] Clear disclosure of data leaving the device
- [ ] Per-room AI disable controls
- [ ] No training, retention, or background upload by default
- [ ] Review-before-send for every generated message

## Platform and operating-system integration

- [ ] Android, iOS, Linux, Windows, macOS, and web support
- [ ] Native share target and share sheet
- [ ] Open-with and save-to-files integration
- [ ] Camera, microphone, contacts, photos, location, and Bluetooth permissions
- [ ] Home-screen widgets and app shortcuts
- [ ] Notification quick reply and call actions
- [ ] Deep/universal links and verified app links
- [ ] Picture-in-picture and media controls
- [ ] System tray/menu bar and unread badge
- [ ] Multi-window, desktop drag-and-drop, and global shortcuts
- [ ] Background launch, startup, and battery optimization guidance
- [ ] Wear OS, watchOS, Android Auto, and CarPlay companion experiences
- [ ] Backup exclusion and secure platform keystore integration
- [ ] Installer, auto-update, release channels, and rollback

## Import, export, backup, and portability

- [ ] Export messages and media in human-readable formats
- [ ] Encrypted archive export and import
- [ ] Export a room, thread, date range, or personal data only
- [ ] Account-data, settings, pins, and space-order portability
- [ ] Migration from other Matrix clients
- [ ] Migration/import from other messaging services where lawful
- [ ] GDPR-style data download and deletion assistance
- [ ] Media archive with checksums and original filenames
- [ ] Print and PDF conversation export
- [ ] Backup verification and restore preview

## Administration and deployment

- [ ] Homeserver discovery, compatibility, and health diagnostics
- [ ] Custom homeserver, identity server, push gateway, and TURN settings
- [ ] Managed configuration and enterprise policy
- [ ] Single sign-on, OIDC, SAML, LDAP, and passkey flows
- [ ] Multi-tenant branding and configuration
- [ ] Feature flags and staged rollout
- [ ] Crash reporting and privacy-respecting telemetry opt-in
- [ ] Performance, sync, media, and call observability
- [ ] Remote configuration with signed policy
- [ ] Data residency and retention controls
- [ ] Admin console links and support bundles
- [ ] Reproducible builds, dependency audit, and software bill of materials
- [ ] Accessibility, security, privacy, and interoperability test suites

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

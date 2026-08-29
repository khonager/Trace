# Product brief

## Purpose

Trace is a privacy-first Matrix client that combines dependable encrypted chat
with optional live drafts, local AI, consent-aware caller audio, and temporary
large-file transfer. It must work with Matrix.org and arbitrary compatible
homeservers rather than locking users to a Trace service.

## Initial platforms

- Android and Linux receive first-class development attention.
- iOS is included from the beginning so platform limitations shape protocols,
  rather than becoming late surprises.
- The visual design is intentionally deferred. Current screens are disposable.

## Core client

- Password and SSO/OIDC homeserver login.
- End-to-end encrypted direct messages and rooms.
- Device verification and encryption-key recovery.
- Text, replies, edits, reactions, redaction, audio messages, images, and files.
- Offline synchronization, local search, notifications, drafts, typing
  indicators, read receipts, blocking, reporting, and device management.
- Multiple accounts and a saved-messages/device-inbox workflow.

## Optional extensions

### Live typing

The sender chooses whether live drafts are disabled, visible to everyone except
selected Matrix users, or visible only to selected users. Draft updates are
encrypted, online-only, short-lived, and absent from room history. Clients that
do not implement the Trace extension simply ignore it.

### Caller audio

Each caller may publish a custom audio excerpt. A recipient must approve the
exact file before it can play. Replacing the file invalidates approval unless
the recipient explicitly trusts future changes from that caller. Silent mode,
Do Not Disturb, platform controls, and recipient policy always win.

- Android and Linux can play approved custom audio in the background.
- iOS can play it while Trace is in the foreground.
- Background and locked iOS calls use an open-licensed sound included in the
  signed app bundle, as required by CallKit.

### AI

Local execution is the default. Supported shapes include an on-device engine,
Ollama or llama.cpp on the local network, and OpenAI-compatible endpoints.
OpenRouter is an optional cloud provider and requires a disclosure before any
decrypted message content leaves the device.

AI has two product modes: a private assistant visible only to the user and a
separate, clearly identified local Matrix bot account for rooms. The room bot is
unavailable while its host device is offline.

Chat exports use an AI-friendly documented format and show a disclaimer. Events
retain author and ownership metadata so downstream tools can distinguish the
user's writing from other participants' writing.

### File transfer

Normal Matrix media remains the default within a homeserver's advertised upload
limit. Larger files prefer encrypted, resumable peer-to-peer transfer while both
ends are online. A future optional relay can hold encrypted data with a strict
expiry when the recipient is offline.

## Optional service, later

A client subscription cannot change arbitrary homeserver limits. A future
service may offer hosted Matrix accounts, storage tiers, expiring file relay,
push infrastructure, and always-online bots. It must remain optional and avoid
artificially withholding standard Matrix functionality.

# Architecture

## Dependency direction

```text
Flutter presentation
        |
Application use cases
        |
Domain policies and models
        |
Ports (Matrix, AI, transfer, call audio, secure storage)
        |
SDK and native adapters
```

Dependencies point downward only. Domain code is plain Dart and must not import
Flutter, Matrix SDK types, platform channels, HTTP clients, databases, or UI
packages. This is the primary mechanism that keeps the future visual redesign
cheap.

## Feature boundaries

- `lib/core/matrix`: Matrix client port and shared protocol-neutral models.
- `lib/core/platform`: capabilities provided by native adapters.
- `lib/core/policy`: reusable user-selection rules.
- `lib/features/live_typing`: live-draft policy and protocol model.
- `lib/features/call_audio`: exact-file approval and playback selection.
- `lib/features/ai`: local/cloud provider boundary and disclosure gate.
- `lib/features/file_transfer`: route selection between Matrix, P2P, and relay.
- `lib/features/chat/application`: attachment picking, composer preferences,
  and provider-neutral media search.
- `lib/infrastructure/matrix`: Matrix Dart SDK and vodozemac adapters.
- `lib/app`: disposable composition and presentation shell.

## Data ownership

- Matrix credentials belong in OS secure storage.
- Decrypted timelines and search indexes belong in an encrypted local database.
- AI indexes and summaries are separate, revocable derived data.
- Custom caller audio is encrypted at rest and addressed by a cryptographic
  content hash.
- Relay services receive ciphertext and expiry metadata, never file keys.
- Media-search providers receive search terms. Brave credentials stay on the
  Trace search relay; GIPHY's provider-required direct-client key is an app
  identifier rather than a stored user credential.

## Platform adapters

Flutter invokes narrow adapters rather than importing native behavior into
widgets. Calling requires native Android Telecom/CallStyle support and native
iOS PushKit/CallKit support. `ClientCapabilities` expresses differences such as
iOS background caller-audio limitations.

## Matrix SDK decision

Trace uses `matrix` 10.x, the Dart Matrix SDK, with `flutter_vodozemac` for
end-to-end encryption. The SDK is isolated behind `MatrixClientPort`; domain
and feature code must never import it. This preserves a migration path if SDK
requirements change and keeps protocol details out of the future UI.

The Matrix Dart SDK is AGPL-3.0-or-later. Distributing or offering a networked
version of Trace must satisfy the corresponding-source and license obligations.
This is a deliberate tradeoff for the more mature Flutter integration.

The SDK database is injected into the client factory. Do not use the SDK's
unencrypted native SQLite example in production: each platform must provide an
encrypted database and keep its key in OS secure storage. Session restoration
calls `Client.init()` only after crypto and that database are available.

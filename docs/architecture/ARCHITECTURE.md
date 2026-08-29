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
- `lib/app`: disposable composition and presentation shell.

## Data ownership

- Matrix credentials belong in OS secure storage.
- Decrypted timelines and search indexes belong in an encrypted local database.
- AI indexes and summaries are separate, revocable derived data.
- Custom caller audio is encrypted at rest and addressed by a cryptographic
  content hash.
- Relay services receive ciphertext and expiry metadata, never file keys.

## Platform adapters

Flutter invokes narrow adapters rather than importing native behavior into
widgets. Calling requires native Android Telecom/CallStyle support and native
iOS PushKit/CallKit support. `ClientCapabilities` expresses differences such as
iOS background caller-audio limitations.

## Matrix SDK decision

No Matrix SDK is linked yet. The stable Dart SDK gives the shortest path but is
AGPL-3.0-only. The official Rust SDK is Apache-2.0 and production-ready but
requires a maintained Flutter FFI layer. The `MatrixClientPort` protects the
rest of the application while project licensing is decided.

This decision must be resolved before implementing authentication or encrypted
timeline storage.

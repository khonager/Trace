# Initial threat model

This document is groundwork, not a completed security review.

## Protected assets

- Matrix access tokens, recovery keys, and device keys.
- Decrypted messages, attachments, local search indexes, and AI memory.
- Live drafts that have not been sent as messages.
- Caller-audio approvals and cached audio.
- Files in direct transfer or temporary relay storage.

## Trust boundaries

- A Matrix homeserver observes metadata and stores encrypted room data.
- Federated homeservers may retain events or media beyond local redaction.
- Push gateways must not receive decrypted message or caller-audio content.
- Cloud AI providers receive plaintext explicitly selected by the user.
- A local AI process is outside the Flutter process and may have its own logs.
- TURN and relay servers observe connection metadata and ciphertext.

## Required controls

- Encrypt rooms, local databases, caller audio, and transfer payloads.
- Keep credentials in platform secure storage and redact them from logs.
- Treat live typing as online-only data with session IDs, monotonic sequence
  numbers, throttling, short expiry, and no offline replay.
- Never preview newly received caller audio automatically.
- Bind caller-audio approval to the content hash; replacement revokes approval.
- Normalize and decode untrusted audio through a constrained native boundary.
- Enforce size, duration, and supported-format limits before caching.
- Make cloud AI opt-in per provider and disclose the selected context.
- Give derived AI indexes independent deletion and rebuild controls.
- Authenticate every P2P transfer, support resumable chunks, and verify a final
  content hash before exposing the file.
- Respect block lists before live typing, calls, AI room participation, or file
  negotiation.

## Explicit non-guarantees

- Redacting a federated Matrix event cannot prove deletion from every remote
  server, backup, screenshot, or previously downloaded client.
- A chat-export disclaimer does not prevent a recipient from misusing exported
  content.
- A compromised endpoint can read content available to that endpoint.

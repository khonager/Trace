# Live typing extension

Status: design draft; no event type is registered or implemented.

## Behavior

- Configuration belongs to the sender and selects recipients by Matrix user ID.
- Updates are encrypted separately for authorized recipient devices.
- Updates are visible only while a compose session is active.
- Empty or expired updates clear the displayed draft.
- Unsupported clients ignore the extension.

## Transport requirements

The transport must not place draft text in the persistent room event graph.
Before selecting Matrix to-device messages or an RTC data channel, prototype and
measure fan-out, device-list changes, offline queues, rate limits, and metadata
leakage. Any queued update must expire before display and must not replay when a
recipient returns online.

Each update contains:

- compose-session identifier;
- monotonically increasing sequence number;
- full text or a defined delta;
- expiry time;
- room and sender binding inside authenticated encrypted content.

The initial implementation should send at most a few updates per second and
immediately end the session when sending, navigating away, disabling the
feature, losing authorization, or blocking a recipient.

# Foreground voice calls

Open Calls and choose an unlocked direct chat with exactly two joined members.
Incoming calls show Answer/Decline controls above the current tab. Connected calls
have mute/unmute and hang-up controls. Only one call can be active or preparing.
An incoming call never requests microphone permission: the adapter supplies an
empty stream during SDK preparation, replaces it with microphone audio only on
Answer, and releases the old stream. Outgoing calls request audio when started.
No camera or screen capture is requested.

This implements legacy one-to-one Matrix VoIP with the Matrix SDK's signalling,
ICE negotiation, remote hang-up, and timeouts, and flutter_webrtc's audio engine.
It uses the homeserver's TURN configuration; without a working TURN service,
some NAT/firewall combinations cannot connect. No public fallback STUN/TURN
service is added. Direct peers can learn each other's network addresses through
WebRTC. Matrix room encryption protects signalling in encrypted rooms; WebRTC
protects media transport. There is no independent call-verification indicator.

The initial scope is foreground-only. Calls stop when the app becomes hidden,
paused, detached, signs out, or the relevant privacy lock closes. Inactive alone
can be a native permission prompt and does not terminate an otherwise unlocked
call. After a pending microphone permission request completes, ownership and
foreground eligibility are checked again and any stale stream is stopped.
Locked and hidden chats are excluded from the calling list and incoming controls.

Incoming notifications are visual while Trace is open. There is no background
push ringing, system Telecom/CallKit integration, ringtone/vibration, call history,
video, group calls, MatrixRTC/Element Call, screen sharing, speaker selector, or
Bluetooth routing control in this version. The existing caller-audio policy is
not activated. A peer must support legacy Matrix voice calling; modern clients
that only offer MatrixRTC will not interoperate with this implementation.

## Design and validation

The Calls tab lists eligible direct chats. Persistent controls above navigation
keep Answer and Hang up accessible from any tab. The layout uses wrapping action
buttons and the existing Material surface palette. Reference:
[phone call controls](../screenshots/voice-call.png).

Automated checks cover eligible chat selection, privacy filtering, answer/decline
and mute actions, microphone cancellation during permission setup, and the actual
Matrix adapter's no-microphone incoming preparation. These tests use fake native
media; a successful build is not proof of working device-to-device audio.

Before release, test two signed-in devices and a compatible legacy Matrix client:

- Record/send/play audio in an encrypted room; deny permission, retry upload,
  cancel, switch chats, and background during recording and permission prompts.
- Dial, answer, hear audio in both directions, mute/unmute, and hang up from each
  side. Decline, let a call expire, and answer on another signed-in device.
- Repeat across different networks with the homeserver TURN service; test a
  broken TURN configuration and disconnect the network during a call.
- Confirm the incoming call does not activate the microphone before Answer.
- Lock/hide the room, background Trace during permission setup and an active call,
  and sign out. Confirm microphone release and no private caller details remain.
- On web, use HTTPS and verify browser microphone permission and remote playback.

The implementation follows the installed Matrix 10.2.2 SDK API. Its
[VoIP documentation](https://github.com/famedly/matrix-dart-sdk/blob/main/lib/src/voip/README.md)
explains the delegate and one-to-one signalling model.

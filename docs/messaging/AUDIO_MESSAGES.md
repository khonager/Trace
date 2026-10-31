# Audio messages

In a chat, choose Add → Record voice message (hold the menu entry to pin it).
Record, stop, then send explicitly. Cancel discards the recording. A failed send
keeps the recording available to retry while the dialog remains open. Permission
is requested only when Record is pressed. Leaving the foreground while recording
cancels it. The destination is fixed when the dialog opens.

Recordings use mono 16 kHz PCM WAV, capped at five minutes (about 9.6 MB). PCM is
held in memory until sending through the existing Matrix attachment pipeline;
encrypted rooms retain Matrix attachment encryption. Other Matrix clients receive
an ordinary m.audio attachment. This does not yet emit MSC3245 voice/waveform data.

Audio attachments have explicit play/pause controls and elapsed time, never
autoplay. Downloads use the existing authenticated/decrypting timeline path.
Playback pauses when the app loses foreground focus. Native playback uses a
private temporary file removed when its widget is disposed; an OS kill can leave
that file in the application's temporary directory. This is the same local UI
protection boundary described in ../security/APP_LOCK.md, not encrypted storage.

Android and iOS declare microphone usage. Browser recording requires a secure
context and permission. Linux needs PulseAudio's parec and FFmpeg for recording,
and GStreamer for playback; these are included in the Nix shell. Codec/device
availability and native permission prompts still require physical-device testing.

Validation covers the WAV container, explicit recording/send behavior, retained
recordings after send failures, and microphone disposal on backgrounding.

Layout reference: [voice message controls](../screenshots/voice-message.png).

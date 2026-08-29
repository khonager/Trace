import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/platform/client_capabilities.dart';
import 'package:trace/core/policy/user_selection_policy.dart';
import 'package:trace/features/call_audio/domain/call_audio_policy.dart';

void main() {
  const caller = '@caller:example.org';
  const approvedHash = 'sha256:approved';
  const policy = CallAudioPolicy(
    callers: UserSelectionPolicy(
      enabled: true,
      mode: UserSelectionMode.only,
      userIds: {caller},
    ),
    approvals: {
      caller: CallAudioApproval(
        callerUserId: caller,
        contentHash: approvedHash,
      ),
    },
  );

  test('changing the audio invalidates exact-file approval', () {
    expect(
      policy.approves(
        callerUserId: caller,
        contentHash: approvedHash,
        headphonesConnected: false,
      ),
      isTrue,
    );
    expect(
      policy.approves(
        callerUserId: caller,
        contentHash: 'sha256:replacement',
        headphonesConnected: false,
      ),
      isFalse,
    );
  });

  test('iOS background calls use an open-licensed bundled theme', () {
    final playback = resolveCallAudioPlayback(
      policy: policy,
      capabilities: const ClientCapabilities.ios(),
      callerUserId: caller,
      contentHash: approvedHash,
      appIsForeground: false,
      headphonesConnected: false,
    );

    expect(playback, CallAudioPlayback.bundledTheme);
  });

  test('iOS foreground calls may use approved custom audio', () {
    final playback = resolveCallAudioPlayback(
      policy: policy,
      capabilities: const ClientCapabilities.ios(),
      callerUserId: caller,
      contentHash: approvedHash,
      appIsForeground: true,
      headphonesConnected: false,
    );

    expect(playback, CallAudioPlayback.customAudio);
  });

  test('Android background calls may use approved custom audio', () {
    final playback = resolveCallAudioPlayback(
      policy: policy,
      capabilities: const ClientCapabilities.android(),
      callerUserId: caller,
      contentHash: approvedHash,
      appIsForeground: false,
      headphonesConnected: false,
    );

    expect(playback, CallAudioPlayback.customAudio);
  });
}

import 'package:trace/core/platform/client_capabilities.dart';
import 'package:trace/core/policy/user_selection_policy.dart';

enum CallAudioPlayback { customAudio, bundledTheme, defaultRingtone }

final class CallAudioApproval {
  const CallAudioApproval({
    required this.callerUserId,
    required this.contentHash,
    this.trustFutureChanges = false,
  });

  final String callerUserId;
  final String contentHash;
  final bool trustFutureChanges;

  bool approves(String candidateHash) {
    return trustFutureChanges || contentHash == candidateHash;
  }
}

/// Receiver-owned controls for caller-selected audio.
final class CallAudioPolicy {
  const CallAudioPolicy({
    required this.callers,
    this.approvals = const <String, CallAudioApproval>{},
    this.onlyWithHeadphones = false,
  });

  final UserSelectionPolicy callers;
  final Map<String, CallAudioApproval> approvals;
  final bool onlyWithHeadphones;

  bool approves({
    required String callerUserId,
    required String contentHash,
    required bool headphonesConnected,
  }) {
    if (!callers.allows(callerUserId)) return false;
    if (onlyWithHeadphones && !headphonesConnected) return false;

    return approvals[callerUserId]?.approves(contentHash) ?? false;
  }
}

CallAudioPlayback resolveCallAudioPlayback({
  required CallAudioPolicy policy,
  required ClientCapabilities capabilities,
  required String callerUserId,
  required String contentHash,
  required bool appIsForeground,
  required bool headphonesConnected,
}) {
  final approved = policy.approves(
    callerUserId: callerUserId,
    contentHash: contentHash,
    headphonesConnected: headphonesConnected,
  );

  if (approved &&
      (appIsForeground
          ? capabilities.customCallAudioInForeground
          : capabilities.customCallAudioInBackground)) {
    return CallAudioPlayback.customAudio;
  }

  if (!appIsForeground && capabilities.bundledCallAudioInBackground) {
    return CallAudioPlayback.bundledTheme;
  }

  return CallAudioPlayback.defaultRingtone;
}

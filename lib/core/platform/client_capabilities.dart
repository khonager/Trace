enum TracePlatform { android, ios, linux }

/// Capabilities are injected so feature code never branches on platform names.
final class ClientCapabilities {
  const ClientCapabilities({
    required this.platform,
    required this.customCallAudioInForeground,
    required this.customCallAudioInBackground,
    required this.bundledCallAudioInBackground,
  });

  const ClientCapabilities.android()
    : platform = TracePlatform.android,
      customCallAudioInForeground = true,
      customCallAudioInBackground = true,
      bundledCallAudioInBackground = true;

  const ClientCapabilities.ios()
    : platform = TracePlatform.ios,
      customCallAudioInForeground = true,
      customCallAudioInBackground = false,
      bundledCallAudioInBackground = true;

  const ClientCapabilities.linux()
    : platform = TracePlatform.linux,
      customCallAudioInForeground = true,
      customCallAudioInBackground = true,
      bundledCallAudioInBackground = true;

  final TracePlatform platform;
  final bool customCallAudioInForeground;
  final bool customCallAudioInBackground;
  final bool bundledCallAudioInBackground;
}

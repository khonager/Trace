enum TransferRoute { matrixMedia, directPeerToPeer, expiringRelay }

final class TransferEnvironment {
  const TransferEnvironment({
    required this.peerOnline,
    required this.relayAvailable,
    required this.matrixUploadLimitBytes,
  });

  final bool peerOnline;
  final bool relayAvailable;
  final int? matrixUploadLimitBytes;
}

TransferRoute chooseTransferRoute({
  required int sizeBytes,
  required TransferEnvironment environment,
}) {
  final uploadLimit = environment.matrixUploadLimitBytes;
  if (uploadLimit == null || sizeBytes <= uploadLimit) {
    return TransferRoute.matrixMedia;
  }
  if (environment.peerOnline) return TransferRoute.directPeerToPeer;
  if (environment.relayAvailable) return TransferRoute.expiringRelay;
  return TransferRoute.matrixMedia;
}

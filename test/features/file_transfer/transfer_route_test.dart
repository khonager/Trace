import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/file_transfer/domain/transfer_route.dart';

void main() {
  test('uses Matrix for files within the homeserver limit', () {
    expect(
      chooseTransferRoute(
        sizeBytes: 10,
        environment: const TransferEnvironment(
          peerOnline: true,
          relayAvailable: true,
          matrixUploadLimitBytes: 100,
        ),
      ),
      TransferRoute.matrixMedia,
    );
  });

  test('uses direct transfer for oversized files when peer is online', () {
    expect(
      chooseTransferRoute(
        sizeBytes: 101,
        environment: const TransferEnvironment(
          peerOnline: true,
          relayAvailable: true,
          matrixUploadLimitBytes: 100,
        ),
      ),
      TransferRoute.directPeerToPeer,
    );
  });

  test('uses an expiring relay when an oversized recipient is offline', () {
    expect(
      chooseTransferRoute(
        sizeBytes: 101,
        environment: const TransferEnvironment(
          peerOnline: false,
          relayAvailable: true,
          matrixUploadLimitBytes: 100,
        ),
      ),
      TransferRoute.expiringRelay,
    );
  });
}

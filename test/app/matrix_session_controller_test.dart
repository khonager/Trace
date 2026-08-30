import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/matrix_session_controller.dart';

void main() {
  group('homeserver normalization', () {
    test('defaults to matrix.org', () {
      expect(
        MatrixSessionController.normalizeHomeserver(''),
        Uri.parse('https://matrix.org'),
      );
    });

    test('discovers the server name from a Matrix ID', () {
      expect(
        MatrixSessionController.normalizeHomeserver(
          '',
          user: '@alice:example.org',
        ),
        Uri.parse('https://example.org'),
      );
    });

    test('rejects insecure remote homeservers', () {
      expect(
        () => MatrixSessionController.normalizeHomeserver(
          'http://example.org',
        ),
        throwsFormatException,
      );
    });
  });
}

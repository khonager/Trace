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
        () => MatrixSessionController.normalizeHomeserver('http://example.org'),
        throwsFormatException,
      );
    });
  });

  test('saved Matrix profiles round-trip without credentials', () {
    final profile = MatrixSavedProfile(
      id: 'profile-1',
      userId: '@alice:example.org',
      displayName: 'Alice',
      homeserver: Uri.parse('https://matrix.example.org'),
      avatarUrl: Uri.parse('mxc://example.org/avatar'),
    );

    final restored = MatrixSavedProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.userId, profile.userId);
    expect(restored.displayName, profile.displayName);
    expect(restored.homeserver, profile.homeserver);
    expect(restored.avatarUrl, profile.avatarUrl);
    expect(profile.toJson(), isNot(contains('password')));
    expect(profile.toJson(), isNot(contains('accessToken')));
  });
}

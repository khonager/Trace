import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.controller});

  final MatrixSessionController? controller;

  @override
  Widget build(BuildContext context) {
    final account = controller?.snapshot.account;
    return ListView(
      key: const Key('settings-page'),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.settings_outlined, size: 28),
        const SizedBox(height: 20),
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        if (account == null)
          const Text(
            'Account, privacy, notifications, and experiments will live here.',
          )
        else ...[
          Card(
            child: ListTile(
              key: const Key('matrix-account-profile'),
              leading: CircleAvatar(
                backgroundImage: account.avatarUrl == null
                    ? null
                    : NetworkImage(account.avatarUrl.toString()),
                child: account.avatarUrl == null
                    ? Text(_initials(account.displayName))
                    : null,
              ),
              title: Text(account.displayName),
              subtitle: Text(
                '${account.userId} · Tap to copy\n${account.homeserver.host}',
              ),
              trailing: IconButton(
                key: const Key('edit-matrix-profile'),
                tooltip: 'Edit profile',
                onPressed: () => _editProfile(context, account),
                icon: const Icon(Icons.edit_outlined),
              ),
              onTap: () => _copyUserId(context, account.userId),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              key: const Key('profile-switcher'),
              leading: const Icon(Icons.switch_account_outlined),
              title: const Text('Profiles'),
              subtitle: Text(
                '${controller!.savedProfiles.length} ${controller!.savedProfiles.length == 1 ? 'profile' : 'profiles'} on this device',
              ),
              children: [
                for (final profile in controller!.savedProfiles)
                  ListTile(
                    key: Key('profile-${profile.id}'),
                    leading: CircleAvatar(
                      backgroundImage: profile.avatarUrl == null
                          ? null
                          : NetworkImage(profile.avatarUrl.toString()),
                      child: profile.avatarUrl == null
                          ? Text(_initials(profile.displayName))
                          : null,
                    ),
                    title: Text(profile.displayName),
                    subtitle: Text(profile.userId),
                    trailing: profile.id == controller!.activeProfileId
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.swap_horiz),
                    onTap:
                        profile.id == controller!.activeProfileId ||
                            controller!.busy
                        ? null
                        : () => _switchProfile(context, profile.id),
                  ),
                const Divider(),
                ListTile(
                  key: const Key('add-profile'),
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Add profile'),
                  subtitle: const Text(
                    'Keep another Matrix session ready for quick testing.',
                  ),
                  onTap: controller!.busy ? null : () => _addProfile(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Set up encryption recovery'),
                  subtitle: const Text(
                    'Create cross-signing and an online key backup.',
                  ),
                  onTap: () => _initializeRecovery(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore encryption keys'),
                  subtitle: const Text(
                    'Use a recovery key or recovery passphrase.',
                  ),
                  onTap: () => _restoreRecovery(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.devices_outlined),
              title: const Text('Devices and sessions'),
              subtitle: const Text('Review Matrix sessions on your account.'),
              children: [
                FutureBuilder(
                  future: controller!.client.getDevices(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Could not load devices: ${snapshot.error}',
                        ),
                      );
                    }
                    final devices = snapshot.data ?? const [];
                    return Column(
                      children: [
                        for (final device in devices)
                          ListTile(
                            leading: Icon(
                              device.verified
                                  ? Icons.verified_user_outlined
                                  : Icons.gpp_maybe_outlined,
                            ),
                            title: Text(
                              '${device.name}${device.isCurrent ? ' · This device' : ''}',
                            ),
                            subtitle: Text(
                              device.verified
                                  ? 'Verified · ${device.id}'
                                  : device.isCurrent
                                  ? 'Not verified · Ask a trusted Matrix session to verify this device'
                                  : 'Not verified · ${device.id}',
                            ),
                            trailing: device.isCurrent
                                ? null
                                : PopupMenuButton<String>(
                                    key: Key('device-actions-${device.id}'),
                                    tooltip: 'Session actions',
                                    onSelected: (action) {
                                      if (action == 'verify') {
                                        _startVerification(context, device.id);
                                      } else if (action == 'remove') {
                                        _removeDevice(context, device);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (!device.verified)
                                        const PopupMenuItem(
                                          value: 'verify',
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.verified_user_outlined,
                                            ),
                                            title: Text('Verify device'),
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.phonelink_erase_outlined,
                                          ),
                                          title: Text('Remove session'),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('matrix-logout-button'),
            onPressed: controller!.busy ? null : () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out and remove local data'),
          ),
        ],
      ],
    );
  }

  Future<void> _initializeRecovery(BuildContext context) async {
    final passphrase = await _askSecret(
      context,
      title: 'Set recovery passphrase',
      action: 'Create recovery',
    );
    if (passphrase == null || !context.mounted) return;
    try {
      final recoveryKey = await controller!.client.initializeRecovery(
        passphrase,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this recovery key'),
          content: SelectableText(recoveryKey),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I saved it'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _copyUserId(BuildContext context, String userId) async {
    await Clipboard.setData(ClipboardData(text: userId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Matrix ID copied.')));
  }

  Future<void> _editProfile(BuildContext context, MatrixAccount account) async {
    final matrixClient = controller!.client;
    if (matrixClient is! MatrixAccountManagementPort) {
      _showError(context, 'Profile editing is unavailable.');
      return;
    }
    final management = matrixClient as MatrixAccountManagementPort;
    final result = await showDialog<_ProfileEditResult>(
      context: context,
      builder: (context) => _ProfileEditDialog(account: account),
    );
    if (result == null || !context.mounted) return;
    try {
      await management.updateProfile(
        displayName: result.displayName,
        avatarBytes: result.avatarBytes,
        avatarName: result.avatarName,
        avatarMimeType: result.avatarMimeType,
        removeAvatar: result.removeAvatar,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _switchProfile(BuildContext context, String profileId) async {
    try {
      await controller!.switchProfile(profileId);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _addProfile(BuildContext context) async {
    try {
      await controller!.addProfile();
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _startVerification(BuildContext context, String deviceId) async {
    try {
      await controller!.startDeviceVerification(deviceId);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _removeDevice(BuildContext context, MatrixDevice device) async {
    final matrixClient = controller!.client;
    if (matrixClient is! MatrixAccountManagementPort) {
      _showError(context, 'Session removal is unavailable.');
      return;
    }
    final management = matrixClient as MatrixAccountManagementPort;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this session?'),
        content: Text(
          '${device.name}\n\nThis signs the device out and invalidates its Matrix access token.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await management.removeDevice(device.id);
    } on MatrixReauthenticationRequiredException {
      if (!context.mounted) return;
      final password = await _askSecret(
        context,
        title: 'Confirm your password',
        action: 'Remove session',
        labelText: 'Matrix account password',
      );
      if (password == null || !context.mounted) return;
      try {
        await management.removeDevice(device.id, password: password);
      } catch (error) {
        if (context.mounted) _showError(context, error);
        return;
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${device.name} was removed.')));
  }

  Future<void> _restoreRecovery(BuildContext context) async {
    final secret = await _askSecret(
      context,
      title: 'Restore encryption keys',
      action: 'Restore',
    );
    if (secret == null || !context.mounted) return;
    try {
      await controller!.client.restoreRecovery(secret);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encryption recovery restored.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<String?> _askSecret(
    BuildContext context, {
    required String title,
    required String action,
    String labelText = 'Recovery key or passphrase',
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          _SecretDialog(title: title, action: action, labelText: labelText),
    );
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Trace will remove the local Matrix session and cached messages from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller!.logout();
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  String _initials(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '?';
    final parts = normalized.split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.account});

  final MatrixAccount account;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameController;
  Uint8List? _avatarBytes;
  String? _avatarName;
  String? _avatarMimeType;
  bool _removeAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _choosePicture() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      setState(() => _error = 'Profile pictures must be 10 MB or smaller.');
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _avatarName = file.name;
      _avatarMimeType = _imageMimeType(file.extension);
      _removeAvatar = false;
      _error = null;
    });
  }

  void _removePicture() {
    setState(() {
      _avatarBytes = null;
      _avatarName = null;
      _avatarMimeType = null;
      _removeAvatar = true;
      _error = null;
    });
  }

  void _save() {
    Navigator.pop(
      context,
      _ProfileEditResult(
        displayName: _nameController.text.trim(),
        avatarBytes: _avatarBytes,
        avatarName: _avatarName,
        avatarMimeType: _avatarMimeType,
        removeAvatar: _removeAvatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? previewImage;
    if (_avatarBytes != null) {
      previewImage = MemoryImage(_avatarBytes!);
    } else if (_removeAvatar || widget.account.avatarUrl == null) {
      previewImage = null;
    } else {
      previewImage = NetworkImage(widget.account.avatarUrl.toString());
    }
    return AlertDialog(
      title: const Text('Edit Matrix profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundImage: previewImage,
              child: previewImage == null
                  ? Text(_profileInitials(_nameController.text))
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _choosePicture,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose picture'),
                ),
                if (widget.account.avatarUrl != null || _avatarBytes != null)
                  TextButton.icon(
                    onPressed: _removePicture,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove picture'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('matrix-display-name-field'),
              controller: _nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SecretDialog extends StatefulWidget {
  const _SecretDialog({
    required this.title,
    required this.action,
    required this.labelText,
  });

  final String title;
  final String action;
  final String labelText;

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      obscureText: true,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('secret-dialog-action'),
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text),
        child: Text(widget.action),
      ),
    ],
  );
}

final class _ProfileEditResult {
  const _ProfileEditResult({
    required this.displayName,
    required this.avatarBytes,
    required this.avatarName,
    required this.avatarMimeType,
    required this.removeAvatar,
  });

  final String displayName;
  final Uint8List? avatarBytes;
  final String? avatarName;
  final String? avatarMimeType;
  final bool removeAvatar;
}

String _profileInitials(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '?';
  return normalized
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

String _imageMimeType(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  'avif' => 'image/avif',
  _ => 'application/octet-stream',
};

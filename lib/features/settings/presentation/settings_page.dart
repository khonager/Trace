import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/settings/application/appearance_settings.dart';
import 'package:trace/features/settings/application/profile_crop.dart';
import 'package:trace/features/settings/application/profile_image_store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.controller, this.appearance});

  final MatrixSessionController? controller;
  final AppearanceSettings? appearance;

  @override
  Widget build(BuildContext context) {
    final account = controller?.snapshot.account;
    final appearance = this.appearance ?? AppearanceScope.maybeOf(context);
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
              leading: InkWell(
                key: const Key('open-own-profile-picture'),
                borderRadius: BorderRadius.circular(40),
                onTap: account.avatarMediaUri == null
                    ? null
                    : () => _showOwnPicture(context, account),
                child: _MatrixAccountAvatar(
                  client: controller!.client,
                  mediaUri: account.avatarMediaUri,
                  initials: _initials(account.displayName),
                ),
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
          if (appearance != null) ...[
            _AppearanceCard(settings: appearance),
            const SizedBox(height: 12),
          ],
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
                    leading: _MatrixAccountAvatar(
                      client: controller!.client,
                      mediaUri: profile.id == controller!.activeProfileId
                          ? account.avatarMediaUri
                          : null,
                      initials: _initials(profile.displayName),
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
      builder: (context) =>
          _ProfileEditDialog(account: account, client: controller!.client),
    );
    if (result == null || !context.mounted) return;
    try {
      await management.updateProfile(
        displayName: result.displayName,
        avatarBytes: result.avatarBytes,
        avatarName: result.avatarBytes == null ? null : 'profile.png',
        avatarMimeType: result.avatarBytes == null ? null : 'image/png',
        removeAvatar: result.removeAvatar,
      );
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    var sourceSaved = true;
    try {
      final key = '${account.homeserver}|${account.userId}';
      if (result.removeAvatar) {
        await const ProfileImageStore().delete(key);
      } else if (result.source != null) {
        await const ProfileImageStore().write(
          key,
          controller!.client.current.account?.avatarMediaUri,
          result.source!,
        );
      }
    } catch (_) {
      sourceSaved = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sourceSaved
              ? 'Profile updated.'
              : 'Profile updated, but the source picture could not be saved on this device.',
        ),
      ),
    );
  }

  Future<void> _showOwnPicture(
    BuildContext context,
    MatrixAccount account,
  ) async {
    final uri = account.avatarMediaUri;
    if (uri == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _OwnPictureDialog(
        name: account.displayName,
        image: controller!.client.downloadMedia(uri),
      ),
    );
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
  const _ProfileEditDialog({required this.account, required this.client});

  final MatrixAccount account;
  final MatrixClientPort client;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _MatrixAccountAvatar extends StatefulWidget {
  const _MatrixAccountAvatar({
    required this.client,
    required this.mediaUri,
    required this.initials,
  });

  final MatrixClientPort client;
  final Uri? mediaUri;
  final String initials;

  @override
  State<_MatrixAccountAvatar> createState() => _MatrixAccountAvatarState();
}

class _MatrixAccountAvatarState extends State<_MatrixAccountAvatar> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MatrixAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUri != widget.mediaUri ||
        oldWidget.client != widget.client) {
      _load();
    }
  }

  void _load() {
    _image = widget.mediaUri == null
        ? null
        : widget.client.downloadMediaThumbnail(widget.mediaUri!);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) => CircleAvatar(
      backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
      child: snapshot.hasData ? null : Text(widget.initials),
    ),
  );
}

class _OwnPictureDialog extends StatefulWidget {
  const _OwnPictureDialog({required this.name, required this.image});

  final String name;
  final Future<Uint8List> image;

  @override
  State<_OwnPictureDialog> createState() => _OwnPictureDialogState();
}

class _OwnPictureDialogState extends State<_OwnPictureDialog> {
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final bytes = await widget.image;
      final format = _pictureFileFormat(bytes);
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save profile picture',
        fileName: 'profile-picture.${format.extension}',
        bytes: bytes,
        mimeType: format.mimeType,
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture saved.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save profile picture.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
      child: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(child: Text('${widget.name} profile picture')),
                IconButton(
                  key: const Key('download-own-profile-picture'),
                  tooltip: 'Download profile picture',
                  onPressed: _saving ? null : _download,
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: widget.image,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load profile picture.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return InteractiveViewer(
                    minScale: .5,
                    maxScale: 6,
                    child: SizedBox.expand(
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

({String extension, String mimeType}) _pictureFileFormat(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return (extension: 'png', mimeType: 'image/png');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return (extension: 'jpg', mimeType: 'image/jpeg');
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return (extension: 'gif', mimeType: 'image/gif');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return (extension: 'webp', mimeType: 'image/webp');
  }
  return (extension: 'img', mimeType: 'application/octet-stream');
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.settings});

  final AppearanceSettings settings;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const Key('appearance-settings'),
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Appearance'),
      subtitle: const Text('Shape the chat view on this device'),
      children: [
        _AppearanceSlider(
          label: 'Sticker size',
          value: settings.stickerSize,
          min: 64,
          max: 256,
          valueLabel: '${settings.stickerSize.round()} px',
          onChanged: (value) => settings.setStickerSize(value),
        ),
        _AppearanceSlider(
          label: 'Chat edge preview',
          value: settings.chatPeekWidth,
          min: 0,
          max: 72,
          valueLabel: settings.chatPeekWidth == 0
              ? 'Off'
              : '${settings.chatPeekWidth.round()} px',
          onChanged: (value) => settings.setChatPeekWidth(value),
        ),
        SwitchListTile(
          title: const Text('Separate direct chats and groups'),
          subtitle: const Text('Show groups in their own tab'),
          value: settings.separateGroups,
          onChanged: settings.setSeparateGroups,
        ),
        SwitchListTile(
          title: const Text('Use chat pictures as backgrounds'),
          value: settings.useProfileBackground,
          onChanged: settings.setUseProfileBackground,
        ),
        if (settings.useProfileBackground)
          _AppearanceSlider(
            label: 'Background blur',
            value: settings.backgroundBlur,
            min: 0,
            max: 80,
            valueLabel: '${settings.backgroundBlur.round()}',
            onChanged: settings.setBackgroundBlur,
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: settings.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restore Trace defaults'),
          ),
        ),
      ],
    ),
  );
}

class _AppearanceSlider extends StatelessWidget {
  const _AppearanceSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    ),
  );
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameController;
  Uint8List? _sourceBytes;
  Future<Uint8List>? _preview;
  bool _pictureChanged = false;
  bool _loadingSource = false;
  bool _saving = false;
  double _zoom = 1;
  double _horizontal = 0;
  double _vertical = 0;
  bool _removeAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.displayName);
    _loadSource();
  }

  Future<void> _loadSource() async {
    final uri = widget.account.avatarMediaUri;
    if (uri == null) return;
    setState(() => _loadingSource = true);
    try {
      final key = '${widget.account.homeserver}|${widget.account.userId}';
      final stored = await const ProfileImageStore().read(key, uri);
      final source =
          stored ??
          ProfileImageSource(bytes: await widget.client.downloadMedia(uri));
      if (mounted && !_pictureChanged) {
        setState(() {
          _sourceBytes = source.bytes;
          _zoom = source.zoom;
          _horizontal = source.horizontal;
          _vertical = source.vertical;
          _updatePreview();
        });
      }
    } catch (_) {
      // A name change and choosing a replacement picture remain available.
    } finally {
      if (mounted) setState(() => _loadingSource = false);
    }
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
    Uint8List source;
    try {
      source = await prepareProfileSource(bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not prepare this picture.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _sourceBytes = source;
      _pictureChanged = true;
      _zoom = 1;
      _horizontal = 0;
      _vertical = 0;
      _updatePreview();
      _removeAvatar = false;
      _error = null;
    });
  }

  void _removePicture() {
    setState(() {
      _sourceBytes = null;
      _preview = null;
      _pictureChanged = true;
      _removeAvatar = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final source = _sourceBytes;
      final cropped = _pictureChanged && !_removeAvatar && source != null
          ? await cropProfileImage(
              source,
              zoom: _zoom,
              horizontal: _horizontal,
              vertical: _vertical,
            )
          : null;
      if (!mounted) return;
      Navigator.pop(
        context,
        _ProfileEditResult(
          displayName: _nameController.text.trim(),
          avatarBytes: cropped,
          source: cropped == null
              ? null
              : ProfileImageSource(
                  bytes: source!,
                  zoom: _zoom,
                  horizontal: _horizontal,
                  vertical: _vertical,
                ),
          removeAvatar: _removeAvatar,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not crop this picture. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Matrix profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingSource && _sourceBytes == null)
              const SizedBox.square(
                dimension: 84,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sourceBytes != null)
              FutureBuilder<Uint8List>(
                future: _preview,
                builder: (context, snapshot) => CircleAvatar(
                  radius: 60,
                  backgroundImage: snapshot.hasData
                      ? MemoryImage(snapshot.data!)
                      : null,
                  child: snapshot.hasData
                      ? null
                      : const Icon(Icons.image_outlined),
                ),
              )
            else
              CircleAvatar(
                radius: 42,
                child: Text(_profileInitials(_nameController.text)),
              ),
            if (_sourceBytes != null && !_removeAvatar) ...[
              const SizedBox(height: 12),
              Text(
                'Frame picture',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _cropSlider('Zoom', _zoom, 1, 4, (value) => _zoom = value),
              _cropSlider(
                'Left / right',
                _horizontal,
                -1,
                1,
                (value) => _horizontal = value,
              ),
              _cropSlider(
                'Up / down',
                _vertical,
                -1,
                1,
                (value) => _vertical = value,
              ),
              const Text(
                'The full image stays on this device for later reframing.',
              ),
            ],
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
                if (widget.account.avatarMediaUri != null ||
                    _sourceBytes != null)
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
          onPressed: _nameController.text.trim().isEmpty || _saving
              ? null
              : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _cropSlider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) update,
  ) => Row(
    children: [
      SizedBox(width: 90, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (next) => setState(() {
            update(next);
            _pictureChanged = true;
            _updatePreview();
          }),
        ),
      ),
    ],
  );

  void _updatePreview() {
    final source = _sourceBytes;
    if (source == null) return;
    _preview = cropProfileImage(
      source,
      zoom: _zoom,
      horizontal: _horizontal,
      vertical: _vertical,
      outputSize: 160,
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
    required this.source,
    required this.removeAvatar,
  });

  final String displayName;
  final Uint8List? avatarBytes;
  final ProfileImageSource? source;
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

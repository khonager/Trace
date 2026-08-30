import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';

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
              leading: CircleAvatar(
                backgroundImage: account.avatarUrl == null
                    ? null
                    : NetworkImage(account.avatarUrl.toString()),
                child: account.avatarUrl == null
                    ? Text(_initials(account.displayName))
                    : null,
              ),
              title: Text(account.displayName),
              subtitle: Text('${account.userId}\n${account.homeserver.host}'),
              isThreeLine: true,
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
                                  : 'Not verified · ${device.id}',
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
  }) async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Recovery key or passphrase',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: Text(action),
          ),
        ],
      ),
    );
    textController.dispose();
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
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

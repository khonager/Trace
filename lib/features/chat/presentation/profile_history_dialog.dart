import 'package:flutter/material.dart';
import '../application/profile_history.dart';

class ProfileHistoryDialog extends StatefulWidget {
  const ProfileHistoryDialog({
    super.key,
    required this.store,
    required this.user,
    required this.name,
    this.avatar,
    required this.onOpenPicture,
  });
  final ProfileHistoryStore store;
  final String user;
  final String name;
  final Uri? avatar;
  final void Function(ProfileHistoryEntry) onOpenPicture;
  @override
  State<ProfileHistoryDialog> createState() => _ProfileHistoryDialogState();
}

class _ProfileHistoryDialogState extends State<ProfileHistoryDialog> {
  String? _error;
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save profile history. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final entries = widget.store.entries(widget.user);
      return AlertDialog(
        title: const Text('Profile history'),
        content: SizedBox(
          width: 440,
          height: 440,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remember profile changes'),
                subtitle: const Text(
                  'Records names and pictures observed on this device from now on.',
                ),
                value: widget.store.enabled(widget.user),
                onChanged: _busy
                    ? null
                    : (value) => _run(() async {
                        await widget.store.setEnabled(widget.user, value);
                        if (value) {
                          await widget.store.observe(
                            widget.user,
                            widget.name,
                            widget.avatar,
                          );
                        }
                      }),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('No saved profiles yet.'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            leading: const Icon(Icons.account_circle_outlined),
                            title: Text(entry.name),
                            subtitle: Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(entry.observedAt.toLocal()),
                            ),
                            onTap: entry.avatar == null
                                ? null
                                : () => widget.onOpenPicture(entry),
                            trailing: IconButton(
                              tooltip: 'Delete profile',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => widget.store.delete(
                                        widget.user,
                                        entry,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy || entries.isEmpty
                ? null
                : () => _run(() => widget.store.clear(widget.user)),
            child: const Text('Delete all'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

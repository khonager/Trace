import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'lock_controller.dart';
import 'lock_widgets.dart';

Future<bool> _unlockGroup(
  BuildContext context,
  LockController locks,
  String id,
) async {
  if (!locks.locked(id)) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          child: LockPrompt(
            locks: locks,
            id: id,
            onUnlocked: () => Navigator.pop(context, true),
          ),
        ),
      ) ??
      false;
}

Future<String?> _createGroup(BuildContext context, LockController locks) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _GroupNameDialog(),
  );
  if (name == null || !context.mounted) return null;
  final id = '${LockController.groupPrefix}$name';
  if (!locks.groups.contains(id)) await editLock(context, locks, id);
  return locks.groups.contains(id) ? id : null;
}

Future<void> hideChat(
  BuildContext context,
  LockController locks,
  String roomId,
) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Hide chat in a group'),
      children: [
        for (final group in locks.groups)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, group),
            child: Text(locks.groupName(group)),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'new'),
          child: const Text('Create group…'),
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  final group = selected == 'new'
      ? await _createGroup(context, locks)
      : selected;
  if (group == null || !context.mounted) return;
  final previous = locks.groupFor(roomId);
  if (previous != null && !await _unlockGroup(context, locks, previous)) return;
  if (!context.mounted || !await _unlockGroup(context, locks, group)) return;
  try {
    await locks.assignRoom(roomId, group);
    locks.hideGroup(group);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not hide chat. Try again.')),
      );
    }
  }
}

class HiddenChatsTile extends StatelessWidget {
  const HiddenChatsTile({super.key, required this.client});
  final MatrixClientPort? client;
  @override
  Widget build(BuildContext context) {
    final locks = LockScope.of(context);
    if (locks == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.visibility_off_outlined),
      title: const Text('Hidden chats'),
      subtitle: const Text(
        'Separate credentials for Work, Private, or your own groups',
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => ListenableBuilder(
          listenable: locks,
          builder: (context, _) => AlertDialog(
            title: const Text('Hidden chats'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unlock a group to show its chats. Groups hide again when you leave the app. Use the hide button in a chat to add it.',
                    ),
                    for (final group in locks.groups) ...[
                      ListTile(
                        title: Text(locks.groupName(group)),
                        subtitle: Text(
                          locks.locked(group)
                              ? 'Hidden'
                              : 'Visible this session',
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit group lock',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => editLock(context, locks, group),
                        ),
                        onTap: () => _unlockGroup(context, locks, group),
                      ),
                      if (!locks.locked(group))
                        for (final roomId in locks.groupRooms(group))
                          ListTile(
                            title: Text(
                              client?.current.rooms
                                      .where((room) => room.id == roomId)
                                      .firstOrNull
                                      ?.name ??
                                  'Chat',
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                try {
                                  await locks.assignRoom(roomId, null);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not unhide chat. Try again.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Unhide'),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _createGroup(context, locks),
                child: const Text('New group'),
              ),
              TextButton(
                onPressed: locks.hideGroups,
                child: const Text('Hide all'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog();
  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New hidden chat group'),
    content: TextField(
      controller: input,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Name',
        hintText: 'Work or Private',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (input.text.trim().isNotEmpty) {
            Navigator.pop(context, input.text.trim());
          }
        },
        child: const Text('Choose lock'),
      ),
    ],
  );
}

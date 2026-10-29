import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'lock_controller.dart';
import 'lock_widgets.dart';

/// Reached only by the unlabelled long press on the Settings heading.
Future<void> showPrivateAccess(
  BuildContext context,
  LockController locks,
  MatrixClientPort? client,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (_) => _AccessPrompt(locks: locks),
  );
  if (choice == null || !context.mounted) return;
  String? group = choice;
  if (choice == 'new') {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _GroupNameDialog(),
    );
    if (name == null || !context.mounted) return;
    group = '${LockController.groupPrefix}$name';
    if (locks.groups.contains(group)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose another name.')));
      return;
    }
    await editLock(context, locks, group);
    if (!context.mounted || !locks.groups.contains(group)) return;
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: LockPrompt(
          locks: locks,
          id: group!,
          onUnlocked: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (unlocked != true || !context.mounted) return;
  }
  if (!locks.locked(group)) {
    await showSpaceManager(context, locks, client, group);
  }
}

Future<void> showSpaceManager(
  BuildContext context,
  LockController locks,
  MatrixClientPort? client,
  String group,
) => showDialog<void>(
  context: context,
  builder: (_) => _SpaceManager(locks: locks, client: client, group: group),
);

class _AccessPrompt extends StatefulWidget {
  const _AccessPrompt({required this.locks});
  final LockController locks;
  @override
  State<_AccessPrompt> createState() => _AccessPromptState();
}

class _AccessPromptState extends State<_AccessPrompt> {
  final input = TextEditingController();
  LockMethod method = LockMethod.passcode;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> open() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final group = await widget.locks.unlockSpace(method, input.text);
      if (!mounted) return;
      if (group != null) {
        Navigator.pop(context, group);
        return;
      }
      input.clear();
      setState(
        () =>
            error = 'Could not open. Check your entry, or wait and try again.',
      );
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Access'),
    content: SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LockMethod>(
              initialValue: method,
              items: [
                for (final value in LockMethod.values.where((m) => m.custom))
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      method = value!;
                      input.clear();
                    }),
            ),
            const SizedBox(height: 16),
            SecretInput(
              key: ValueKey(method),
              method: method,
              controller: input,
              enabled: !busy,
              onSubmitted: open,
            ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, 'new'),
        child: const Text('Set up'),
      ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : open,
        child: Text(busy ? 'Checking…' : 'Open'),
      ),
    ],
  );
}

class _SpaceManager extends StatefulWidget {
  const _SpaceManager({
    required this.locks,
    required this.client,
    required this.group,
  });
  final LockController locks;
  final MatrixClientPort? client;
  final String group;
  @override
  State<_SpaceManager> createState() => _SpaceManagerState();
}

class _SpaceManagerState extends State<_SpaceManager> {
  bool busy = false;
  String? error;
  Future<void> assign(String room, bool selected) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final locks = widget.locks;
      if (selected && locks.groupFor(room) == null && locks.locked(room)) {
        final unlocked = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            child: LockPrompt(
              locks: locks,
              id: room,
              onUnlocked: () => Navigator.pop(context, true),
            ),
          ),
        );
        if (unlocked != true) return;
      }
      await locks.assignRoom(room, selected ? widget.group : null);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update this chat. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.locks,
    builder: (context, _) {
      final locks = widget.locks;
      if (locks.locked(widget.group) || !locks.groups.contains(widget.group)) {
        return const SizedBox.shrink();
      }
      final members = locks.groupRooms(widget.group);
      final rooms =
          widget.client?.current.rooms
              .where(
                (room) =>
                    !room.isSpace &&
                    room.membership == MatrixRoomMembership.joined &&
                    (locks.groupFor(room.id) == null ||
                        locks.groupFor(room.id) == widget.group),
              )
              .toList() ??
          <MatrixRoom>[];
      return AlertDialog(
        title: Text(locks.groupName(widget.group)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected chats appear only while this space is open. It closes when you leave Trace or after two minutes without activity.',
                ),
                const SizedBox(height: 12),
                for (final room in rooms)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(room.name),
                    value: members.contains(room.id),
                    onChanged: busy
                        ? null
                        : (selected) => assign(room.id, selected!),
                  ),
                if (rooms.isEmpty) const Text('No chats available.'),
                if (error != null) Text(error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => editLock(context, locks, widget.group),
            child: const Text('Change credential'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              locks.hideGroup(widget.group);
            },
            child: const Text('Close space'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
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
    title: const Text('Set up a space'),
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
        child: const Text('Choose credential'),
      ),
    ],
  );
}

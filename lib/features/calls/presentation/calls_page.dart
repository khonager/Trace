import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/calls/application/call_service.dart';
import 'package:trace/features/lock/lock_widgets.dart';

class CallsPage extends StatelessWidget {
  const CallsPage({super.key, this.client, this.calls});
  final MatrixClientPort? client;
  final CallService? calls;

  @override
  Widget build(BuildContext context) {
    final service = calls;
    if (service == null || client == null) {
      return const Center(
        key: Key('calls-page'),
        child: Text('Sign in to make voice calls.'),
      );
    }
    final locks = LockScope.of(context);
    return StreamBuilder<MatrixClientSnapshot>(
      stream: client!.snapshots,
      initialData: client!.current,
      builder: (context, snapshot) {
        final rooms =
            (snapshot.data?.rooms ?? const <MatrixRoom>[])
                .where(
                  (room) =>
                      canCallRoom(room) &&
                      locks?.hidden(room.id) != true &&
                      locks?.locked(room.id) != true,
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return ListenableBuilder(
          listenable: service,
          builder: (context, _) => ListView(
            key: const Key('calls-page'),
            padding: const EdgeInsets.all(24),
            children: [
              Text('Calls', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Voice calls work while Trace is open. Choose a direct chat to call.',
              ),
              const SizedBox(height: 20),
              if (rooms.isEmpty)
                const Text(
                  'No available direct chats. Start a chat from Chats, or unlock a protected chat first.',
                ),
              for (final room in rooms)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(room.name),
                  trailing: IconButton(
                    tooltip: 'Call ${room.name}',
                    onPressed: service.busy || service.current != null
                        ? null
                        : () => service.start(room),
                    icon: const Icon(Icons.call_outlined),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Kept above navigation so an incoming call can be answered from any tab.
class CallControls extends StatelessWidget {
  const CallControls({super.key, required this.calls, required this.client});
  final CallService calls;
  final MatrixClientPort client;
  @override
  Widget build(BuildContext context) {
    final locks = LockScope.of(context);
    return ListenableBuilder(
      listenable: calls,
      builder: (context, _) {
        final call = calls.current;
        if (call == null && calls.error == null) return const SizedBox.shrink();
        if (call != null &&
            (locks?.hidden(call.roomId) == true ||
                locks?.locked(call.roomId) == true)) {
          return const SizedBox.shrink();
        }
        final rooms = client.current.rooms.where(
          (room) => room.id == call?.roomId,
        );
        final name = rooms.isEmpty ? 'Voice call' : rooms.first.name;
        final status = call == null
            ? ''
            : switch (call.phase) {
                CallPhase.preparing => 'Preparing call…',
                CallPhase.ringing =>
                  call.incoming ? 'Incoming voice call' : 'Calling…',
                CallPhase.connecting => 'Connecting…',
                CallPhase.connected =>
                  call.muted ? 'Connected · Microphone muted' : 'Connected',
                CallPhase.ending => 'Ending call…',
              };
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (call != null) ...[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Semantics(liveRegion: true, child: Text(status)),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      if (call.canAnswer)
                        FilledButton.icon(
                          onPressed: calls.busy ? null : calls.answer,
                          icon: const Icon(Icons.call),
                          label: const Text('Answer'),
                        ),
                      if (call.phase == CallPhase.connected)
                        OutlinedButton.icon(
                          onPressed: calls.busy ? null : calls.toggleMute,
                          icon: Icon(call.muted ? Icons.mic_off : Icons.mic),
                          label: Text(call.muted ? 'Unmute' : 'Mute'),
                        ),
                      TextButton.icon(
                        onPressed: calls.end,
                        icon: const Icon(Icons.call_end),
                        label: Text(call.canAnswer ? 'Decline' : 'Hang up'),
                      ),
                    ],
                  ),
                ],
                if (calls.error != null)
                  Row(
                    children: [
                      Expanded(child: Text(calls.error!)),
                      IconButton(
                        tooltip: 'Dismiss call error',
                        onPressed: calls.clearError,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

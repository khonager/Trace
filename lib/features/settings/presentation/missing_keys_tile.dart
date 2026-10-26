import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/request_missing_keys.dart';

class MissingKeysTile extends StatefulWidget {
  const MissingKeysTile({super.key, required this.client});
  final MatrixClientPort client;
  @override
  State<MissingKeysTile> createState() => _MissingKeysTileState();
}

class _MissingKeysTileState extends State<MissingKeysTile> {
  bool _busy = false;
  bool _cancelled = false;
  String? _status;

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cancelled = false;
    });
    final result = await requestAllMissingKeys(
      widget.client,
      cancelled: () => _cancelled || !mounted,
      onProgress: (name, completed, total) {
        if (mounted) {
          setState(
            () => _status = 'Checking ${completed + 1} of $total chats: $name',
          );
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status =
          '${result.cancelled ? 'Stopped. ' : ''}Requested ${result.requested} missing sessions.'
          '${result.failedRooms > 0 ? ' ${result.failedRooms} chats could not be checked. Try again when connected.' : ''}'
          ' Other devices may need to approve the requests. Keys that no device or backup retains cannot be recovered.';
    });
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: const Key('request-all-missing-keys'),
    leading: _busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.key_outlined),
    title: const Text('Request all missing keys'),
    subtitle: Text(
      _status ??
          'Checks older accessible history in all encrypted chats. This may take a while.',
    ),
    onTap: _busy ? null : _request,
    trailing: _busy
        ? IconButton(
            tooltip: 'Stop requesting keys',
            icon: const Icon(Icons.stop),
            onPressed: () => setState(() {
              _cancelled = true;
              _status = 'Stopping after the current request…';
            }),
          )
        : const Icon(Icons.chevron_right),
  );
}

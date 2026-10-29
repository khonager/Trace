import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:trace/features/lock/lock_controller.dart';

class LockScope extends InheritedNotifier<LockController> {
  const LockScope({
    super.key,
    required LockController controller,
    required super.child,
  }) : super(notifier: controller);
  static LockController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LockScope>()?.notifier;
}

class LockHost extends StatefulWidget {
  const LockHost({
    super.key,
    required this.child,
    this.controller,
    this.onSpacesClosed,
  });
  final Widget child;
  final LockController? controller;
  final VoidCallback? onSpacesClosed;
  @override
  State<LockHost> createState() => _LockHostState();
}

class _LockHostState extends State<LockHost> with WidgetsBindingObserver {
  late final LockController locks = widget.controller ?? LockController();
  bool obscured = false;
  bool _concealSpace = false;
  Set<String> _openSpaces = {};

  void _spacesChanged() {
    final open = locks.groups.where((id) => !locks.locked(id)).toSet();
    final closed = _openSpaces.any((id) => !open.contains(id));
    _openSpaces = open;
    if (closed) widget.onSpacesClosed?.call();
  }

  bool _keyActivity(KeyEvent event) {
    locks.recordActivity();
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openSpaces = locks.groups.where((id) => !locks.locked(id)).toSet();
    locks.addListener(_spacesChanged);
    HardwareKeyboard.instance.addHandler(_keyActivity);
    if (!locks.ready) unawaited(locks.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locks.removeListener(_spacesChanged);
    HardwareKeyboard.instance.removeHandler(_keyActivity);
    if (widget.controller == null) locks.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      obscured = state != AppLifecycleState.resumed;
      _concealSpace = obscured && (_concealSpace || locks.hasOpenGroups);
    });
    // Native authentication itself temporarily makes the app inactive.
    if (!locks.authenticating && state != AppLifecycleState.resumed) {
      locks.lockAll();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      locks.lockAll();
    }
  }

  @override
  Widget build(BuildContext context) => LockScope(
    controller: locks,
    child: ListenableBuilder(
      listenable: locks,
      builder: (context, _) {
        final id = locks.locked(LockController.app)
            ? LockController.app
            : locks.resumeLock;
        final covered =
            !locks.ready ||
            (obscured && (locks.hasVisibleLocks || _concealSpace)) ||
            id != null;
        return Stack(
          children: [
            Offstage(
              offstage: covered,
              child: ExcludeFocus(
                excluding: covered,
                child: Listener(
                  onPointerDown: (_) => locks.recordActivity(),
                  onPointerMove: (_) => locks.recordActivity(),
                  onPointerSignal: (_) => locks.recordActivity(),
                  child: TickerMode(enabled: !covered, child: widget.child),
                ),
              ),
            ),
            if (covered)
              Positioned.fill(
                child: Material(
                  child: SafeArea(
                    child: !locks.ready
                        ? Center(
                            child: locks.error == null
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(locks.error!),
                                      TextButton(
                                        onPressed: locks.load,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                          )
                        : obscured
                        ? locks.hasVisibleLocks
                              ? const Center(
                                  child: Icon(Icons.lock_outline, size: 48),
                                )
                              : const SizedBox.expand()
                        : LockPrompt(key: ValueKey(id), locks: locks, id: id!),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class LockPrompt extends StatefulWidget {
  const LockPrompt({
    super.key,
    required this.locks,
    required this.id,
    this.onUnlocked,
  });
  final LockController locks;
  final String id;
  final VoidCallback? onUnlocked;
  @override
  State<LockPrompt> createState() => _LockPromptState();
}

class _LockPromptState extends State<LockPrompt> {
  final input = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> unlock() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final success = await widget.locks.verify(widget.id, secret: input.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!success) {
        input.clear();
        error =
            'Could not unlock. Check your credential or device settings. After 5 failures, wait 30 seconds.';
      }
    });
    if (success) widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.locks.method(widget.id);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 16),
              Text(
                widget.id == LockController.app
                    ? 'Trace is locked'
                    : widget.id.startsWith(LockController.groupPrefix)
                    ? 'Unlock ${widget.locks.groupName(widget.id)} chats'
                    : 'Chat is locked',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (method?.custom ?? false)
                SecretInput(
                  method: method!,
                  controller: input,
                  enabled: !busy,
                  onSubmitted: unlock,
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!, semanticsLabel: error),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : unlock,
                child: Text(busy ? 'Checking…' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecretInput extends StatefulWidget {
  const SecretInput({
    super.key,
    required this.method,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });
  final LockMethod method;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;
  @override
  State<SecretInput> createState() => _SecretInputState();
}

class _SecretInputState extends State<SecretInput> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    // Reset text, selection and composing together, then keep the existing
    // input connection focused so the keyboard receives the empty value.
    widget.controller.value = const TextEditingValue(
      selection: TextSelection.collapsed(offset: 0),
    );
    _focusNode.requestFocus();
  }

  void add(int dot) {
    if (!widget.enabled || widget.controller.text.contains('$dot')) return;
    setState(() => widget.controller.text += '$dot');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.method != LockMethod.pattern) {
      return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: !widget.enabled,
        enableInteractiveSelection: widget.enabled,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: widget.method == LockMethod.passcode
            ? TextInputType.number
            : TextInputType.visiblePassword,
        inputFormatters: widget.method == LockMethod.passcode
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: widget.method.label,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear credential',
                    onPressed: widget.enabled ? _clear : null,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        onSubmitted: (_) => widget.onSubmitted?.call(),
      );
    }
    return Column(
      children: [
        const Text('Draw or tap dots in order.'),
        SizedBox(
          width: 240,
          height: 240,
          child: GestureDetector(
            onPanStart: widget.enabled
                ? (_) => setState(() => widget.controller.clear())
                : null,
            onPanUpdate: widget.enabled
                ? (details) {
                    final p = details.localPosition;
                    final col = (p.dx / 80).floor();
                    final row = (p.dy / 80).floor();
                    if (col >= 0 &&
                        col < 3 &&
                        row >= 0 &&
                        row < 3 &&
                        (p - Offset(col * 80 + 40, row * 80 + 40)).distance <
                            30) {
                      add(row * 3 + col + 1);
                    }
                  }
                : null,
            child: GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var dot = 1; dot <= 9; dot++)
                  IconButton(
                    tooltip: 'Dot $dot',
                    onPressed: widget.enabled ? () => add(dot) : null,
                    icon: Icon(
                      widget.controller.text.contains('$dot')
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: widget.enabled
              ? () => setState(() => widget.controller.clear())
              : null,
          child: const Text('Clear pattern'),
        ),
      ],
    );
  }
}

class ChatLockGuard extends StatelessWidget {
  const ChatLockGuard({super.key, required this.id, required this.child});
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final locks = LockScope.of(context);
    if (locks == null) return child;
    if (locks.hidden(id)) return const SizedBox.shrink();
    if (locks.locked(id)) {
      return Material(
        child: LockPrompt(locks: locks, id: id),
      );
    }
    return child;
  }
}

class LockSettingsTile extends StatelessWidget {
  const LockSettingsTile({
    super.key,
    this.id = LockController.app,
    this.onPrivateAccess,
  });
  final String id;
  final VoidCallback? onPrivateAccess;
  @override
  Widget build(BuildContext context) {
    final locks = LockScope.of(context);
    if (locks == null) return const SizedBox.shrink();
    final tile = ListTile(
      leading: const Icon(Icons.lock_outline),
      title: Text(id == LockController.app ? 'App lock' : 'Chat lock'),
      subtitle: Text(locks.method(id)?.label ?? 'Off'),
      onTap: () => editLock(context, locks, id),
    );
    if (onPrivateAccess == null) return tile;
    return RawGestureDetector(
      // A deliberate three-second hold; ordinary taps still edit app lock.
      excludeFromSemantics: true,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(seconds: 3),
              ),
              (recognizer) => recognizer.onLongPress = onPrivateAccess,
            ),
      },
      child: tile,
    );
  }
}

Future<void> editLock(
  BuildContext context,
  LockController locks,
  String id,
) async {
  if (locks.enabled(id)) {
    final authorized = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: LockPrompt(
          locks: locks,
          id: id,
          onUnlocked: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (authorized != true || !context.mounted) return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _LockEditor(locks: locks, id: id),
  );
}

class _LockEditor extends StatefulWidget {
  const _LockEditor({required this.locks, required this.id});
  final LockController locks;
  final String id;
  @override
  State<_LockEditor> createState() => _LockEditorState();
}

class _LockEditorState extends State<_LockEditor> {
  LockMethod selected = LockMethod.passcode;
  final secret = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    secret.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save({bool disable = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!disable) {
        if (selected.custom) {
          final validation = LockController.validate(selected, secret.text);
          if (validation != null) throw FormatException(validation);
          if (secret.text != confirmation.text) {
            throw const FormatException('The two entries do not match.');
          }
        } else if (!await widget.locks.verify(widget.id, candidate: selected)) {
          throw const FormatException(
            'Device authentication unavailable or canceled. Choose a custom lock or check device settings.',
          );
        }
      }
      await widget.locks.configure(
        widget.id,
        disable ? null : selected,
        secret: secret.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Could not save lock settings. Unlock again and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.id == LockController.app
          ? 'App lock'
          : widget.id.startsWith(LockController.groupPrefix)
          ? '${widget.locks.groupName(widget.id)} access'
          : 'Chat lock',
    ),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional, on this device only. Locks again when you leave the app. Keep custom credentials safe: Trace cannot recover them.',
            ),
            if (widget.id.startsWith(LockController.groupPrefix))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Use a different credential for each space. App lock is independent.',
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LockMethod>(
              initialValue: selected,
              isExpanded: true,
              items: [
                for (final method in LockMethod.values.where(
                  (method) =>
                      !widget.id.startsWith(LockController.groupPrefix) ||
                      method.custom,
                ))
                  DropdownMenuItem(value: method, child: Text(method.label)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      selected = value!;
                      secret.clear();
                      confirmation.clear();
                    }),
            ),
            if (selected.custom) ...[
              const SizedBox(height: 16),
              SecretInput(
                key: ValueKey('new-$selected'),
                method: selected,
                controller: secret,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              const Text('Repeat to confirm'),
              SecretInput(
                key: ValueKey('confirm-$selected'),
                method: selected,
                controller: confirmation,
                enabled: !busy,
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Uses your enrolled device credentials.'),
              ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.locks.enabled(widget.id))
        TextButton(
          onPressed: busy ? null : () => save(disable: true),
          child: const Text('Turn off'),
        ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Saving…' : 'Enable'),
      ),
    ],
  );
}

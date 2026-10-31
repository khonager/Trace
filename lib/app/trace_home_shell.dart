import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/features/calls/application/call_service.dart';
import 'package:trace/features/calls/presentation/calls_page.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';
import 'package:trace/features/lock/lock_controller.dart';
import 'package:trace/features/lock/lock_widgets.dart';
import 'package:trace/features/settings/application/appearance_settings.dart';
import 'package:trace/features/settings/presentation/settings_page.dart';

enum TracePage { chats, calls, settings }

class TraceHomeShell extends StatefulWidget {
  const TraceHomeShell({super.key, this.controller});

  final MatrixSessionController? controller;

  @override
  State<TraceHomeShell> createState() => _TraceHomeShellState();
}

class _TraceHomeShellState extends State<TraceHomeShell>
    with WidgetsBindingObserver {
  CallService? _calls;
  LockController? _locks;
  bool _foreground = true;
  TracePage _page = TracePage.chats;
  final AppearanceSettings _appearance = AppearanceSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final client = widget.controller?.client;
    if (client is CallingClientPort) {
      _calls = (client as CallingClientPort).calls;
    }
    unawaited(_appearance.load().catchError((Object _) {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locks = LockScope.of(context);
    _updateCallAvailability();
  }

  void _updateCallAvailability() => _calls?.setAvailability(
    foreground:
        _foreground &&
        (_locks?.ready ?? true) &&
        _locks?.locked(LockController.app) != true,
    roomAllowed: (id) =>
        _locks?.hidden(id) != true &&
        _locks?.locked(id) != true &&
        (widget.controller?.client.current.rooms.any(
              (room) => room.id == id && canCallRoom(room),
            ) ??
            false),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive can be the microphone permission prompt. Hidden/paused mean
    // leaving the app; those states cancel setup and any established call.
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    _updateCallAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calls?.setAvailability(foreground: false, roomAllowed: (_) => false);
    _appearance.dispose();
    super.dispose();
  }

  Widget _navigation() => NavigationBar(
    key: const Key('page-toolbar'),
    selectedIndex: _page.index,
    onDestinationSelected: (index) =>
        setState(() => _page = TracePage.values[index]),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: 'Chats',
      ),
      NavigationDestination(
        icon: Icon(Icons.call_outlined),
        selectedIcon: Icon(Icons.call),
        label: 'Calls',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppearanceScope(
    settings: _appearance,
    child: ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Scaffold(
          body: Column(
            children: [
              if (_calls != null && widget.controller != null)
                CallControls(calls: _calls!, client: widget.controller!.client),
              Expanded(
                child: IndexedStack(
                  index: _page.index,
                  children: [
                    ChatsPage(
                      client: widget.controller?.client,
                      navigation: _navigation(),
                    ),
                    CallsPage(client: widget.controller?.client, calls: _calls),
                    SettingsPage(
                      controller: widget.controller,
                      appearance: _appearance,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _page == TracePage.chats ? null : _navigation(),
        ),
      ),
    ),
  );
}

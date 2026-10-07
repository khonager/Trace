import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';
import 'package:trace/features/calls/presentation/calls_page.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';
import 'package:trace/features/settings/presentation/settings_page.dart';
import 'package:trace/features/settings/application/appearance_settings.dart';

enum TracePage { chats, calls, settings }

class TraceHomeShell extends StatefulWidget {
  const TraceHomeShell({super.key, this.controller});

  final MatrixSessionController? controller;

  @override
  State<TraceHomeShell> createState() => _TraceHomeShellState();
}

class _TraceHomeShellState extends State<TraceHomeShell> {
  TracePage _page = TracePage.chats;
  final AppearanceSettings _appearance = AppearanceSettings();

  @override
  void initState() {
    super.initState();
    unawaited(_appearance.load().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
      settings: _appearance,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Scaffold(
            body: IndexedStack(
              index: _page.index,
              children: [
                ChatsPage(client: widget.controller?.client),
                const CallsPage(),
                SettingsPage(
                  controller: widget.controller,
                  appearance: _appearance,
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              key: const Key('page-toolbar'),
              selectedIndex: _page.index,
              onDestinationSelected: (index) {
                setState(() => _page = TracePage.values[index]);
              },
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
            ),
          ),
        ),
      ),
    );
  }
}

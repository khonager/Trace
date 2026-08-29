import 'package:flutter/material.dart';
import 'package:trace/features/calls/presentation/calls_page.dart';
import 'package:trace/features/chat/presentation/chats_page.dart';
import 'package:trace/features/settings/presentation/settings_page.dart';

enum TracePage { chats, calls, settings }

class TraceHomeShell extends StatefulWidget {
  const TraceHomeShell({super.key});

  @override
  State<TraceHomeShell> createState() => _TraceHomeShellState();
}

class _TraceHomeShellState extends State<TraceHomeShell> {
  TracePage _page = TracePage.chats;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Scaffold(
              body: IndexedStack(
                index: _page.index,
                children: const [ChatsPage(), CallsPage(), SettingsPage()],
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
      ),
    );
  }
}

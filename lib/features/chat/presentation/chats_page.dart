import 'package:flutter/material.dart';

const double _overviewHeaderHeight = 82;
const double _conversationRowHeight = 84;
const double _chatRailWidth = 58;
const double _chatPeekWidth = 28;

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with TickerProviderStateMixin {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _overviewScrollController = ScrollController();

  final List<_Conversation> _conversations = _mockConversations();
  late final AnimationController _workspaceTransition;
  late final AnimationController _avatarPromotion;
  int _activeConversation = 0;
  bool _dragIsActive = false;
  double _transitionTravel = 1;

  @override
  void initState() {
    super.initState();
    _workspaceTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _avatarPromotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _workspaceTransition.dispose();
    _avatarPromotion.dispose();
    _overviewScrollController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _openConversation(int index) async {
    setState(() {
      _activeConversation = index;
    });
    await _settleWorkspace(open: true);
  }

  Future<void> _closeConversation() => _settleWorkspace(open: false);

  Future<void> _settleWorkspace({required bool open}) async {
    final target = open ? 1.0 : 0.0;
    final distance = (target - _workspaceTransition.value).abs();
    final workspaceDuration = Duration(
      milliseconds: 140 + (distance * 180).round(),
    );
    await Future.wait([
      _workspaceTransition.animateTo(
        target,
        duration: workspaceDuration,
        curve: Curves.easeOutCubic,
      ),
      _avatarPromotion.animateTo(
        target,
        duration: open ? const Duration(milliseconds: 220) : workspaceDuration,
        curve: Curves.easeOutCubic,
      ),
    ]);
    if (open && mounted) {
      setState(() => _conversations[_activeConversation].unreadCount = 0);
    }
  }

  void _selectConversation(int index) {
    setState(() {
      _activeConversation = index;
      _conversations[index].unreadCount = 0;
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _workspaceTransition.stop();
    if (_workspaceTransition.value < 0.5) {
      _avatarPromotion.value = 0;
      final listY =
          details.localPosition.dy -
          _overviewHeaderHeight +
          (_overviewScrollController.hasClients
              ? _overviewScrollController.offset
              : 0);
      final index = listY ~/ _conversationRowHeight;
      if (listY < 0 || index < 0 || index >= _conversations.length) {
        _dragIsActive = false;
        return;
      }
      setState(() => _activeConversation = index);
    }
    _dragIsActive = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragIsActive) return;
    _workspaceTransition.value =
        (_workspaceTransition.value - details.delta.dx / _transitionTravel)
            .clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragIsActive) return;
    _dragIsActive = false;
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        velocity < -600 ||
        (velocity <= 600 && _workspaceTransition.value >= 0.5);
    _settleWorkspace(open: shouldOpen);
  }

  void _onHorizontalDragCancel() {
    if (!_dragIsActive) return;
    _dragIsActive = false;
    _settleWorkspace(open: _workspaceTransition.value >= 0.5);
  }

  void _onRailTap(int index) {
    if (_workspaceTransition.value >= 0.5) {
      _selectConversation(index);
    } else {
      _openConversation(index);
    }
  }

  void _sendMessage() {
    final body = _composerController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _conversations[_activeConversation].messages.add(
        _ChatMessage(body: body, sentByMe: true),
      );
      _conversations[_activeConversation].preview = 'You: $body';
    });
    _composerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final initialWorkspaceLeft = width - _chatRailWidth - _chatPeekWidth;
        _transitionTravel = initialWorkspaceLeft;

        return GestureDetector(
          key: const Key('chat-workspace'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _onHorizontalDragCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _workspaceTransition,
              _avatarPromotion,
              _overviewScrollController,
            ]),
            builder: (context, _) {
              final progress = _workspaceTransition.value;
              final overviewLeft = -initialWorkspaceLeft * progress;
              final workspaceLeft = initialWorkspaceLeft * (1 - progress);
              final scrollOffset = _overviewScrollController.hasClients
                  ? _overviewScrollController.offset
                  : 0.0;

              return ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: overviewLeft,
                      top: 0,
                      bottom: 0,
                      width: initialWorkspaceLeft,
                      child: _ChatOverview(
                        conversations: _conversations,
                        scrollController: _overviewScrollController,
                        onOpen: _openConversation,
                      ),
                    ),
                    Positioned(
                      left: workspaceLeft,
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: _FocusedChatWorkspace(
                        conversations: _conversations,
                        activeIndex: _activeConversation,
                        avatarPromotion: _avatarPromotion.value,
                        overviewScrollOffset: scrollOffset,
                        composerController: _composerController,
                        onBack: _closeConversation,
                        onSelect: _onRailTap,
                        onSend: _sendMessage,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ChatOverview extends StatelessWidget {
  const _ChatOverview({
    required this.conversations,
    required this.scrollController,
    required this.onOpen,
  });

  final List<_Conversation> conversations;
  final ScrollController scrollController;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _overviewHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chats',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: () {},
                    icon: const Icon(Icons.edit_square),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemExtent: _conversationRowHeight,
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _ConversationRow(
                  key: Key('conversation-row-$index'),
                  conversation: conversation,
                  onTap: () => onOpen(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final _Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              conversation.time,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _FocusedChatWorkspace extends StatelessWidget {
  const _FocusedChatWorkspace({
    required this.conversations,
    required this.activeIndex,
    required this.avatarPromotion,
    required this.overviewScrollOffset,
    required this.composerController,
    required this.onBack,
    required this.onSelect,
    required this.onSend,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final double avatarPromotion;
  final double overviewScrollOffset;
  final TextEditingController composerController;
  final VoidCallback onBack;
  final ValueChanged<int> onSelect;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          _SharedConversationRail(
            key: const Key('neighbor-chat-rail'),
            conversations: conversations,
            activeIndex: activeIndex,
            avatarPromotion: avatarPromotion,
            overviewScrollOffset: overviewScrollOffset,
            onSelect: onSelect,
          ),
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _ConversationView(
                  key: Key(
                    'conversation-view-${conversations[activeIndex].id}',
                  ),
                  conversation: conversations[activeIndex],
                  composerController: composerController,
                  onBack: onBack,
                  onSend: onSend,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedConversationRail extends StatelessWidget {
  const _SharedConversationRail({
    super.key,
    required this.conversations,
    required this.activeIndex,
    required this.avatarPromotion,
    required this.overviewScrollOffset,
    required this.onSelect,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final double avatarPromotion;
  final double overviewScrollOffset;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final promotion = Curves.easeOutCubic.transform(avatarPromotion);
    const rowAvatarInset = (_conversationRowHeight - 50) / 2;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: _chatRailWidth,
        child: ClipRect(
          child: Stack(
            children: [
              for (var index = 0; index < conversations.length; index++)
                Positioned(
                  left: 4,
                  top: index == activeIndex
                      ? _lerp(
                          _overviewHeaderHeight +
                              index * _conversationRowHeight +
                              rowAvatarInset -
                              overviewScrollOffset,
                          10,
                          promotion,
                        )
                      : _overviewHeaderHeight +
                            index * _conversationRowHeight +
                            rowAvatarInset -
                            overviewScrollOffset,
                  width: 50,
                  child: _RailConversationButton(
                    conversation: conversations[index],
                    selected: index == activeIndex,
                    onTap: () => onSelect(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _lerp(double start, double end, double progress) =>
    start + (end - start) * progress;

class _RailConversationButton extends StatelessWidget {
  const _RailConversationButton({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final _Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${conversation.name}',
      child: InkWell(
        key: Key('rail-${conversation.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 48 : 40,
                height: selected ? 48 : 40,
                decoration: BoxDecoration(
                  border: selected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 2,
                        )
                      : null,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _InitialsAvatar(
                  initials: conversation.initials,
                  diameter: selected ? 42 : 40,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              if (conversation.unreadCount > 0)
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: _UnreadBadge(count: conversation.unreadCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationView extends StatelessWidget {
  const _ConversationView({
    super.key,
    required this.conversation,
    required this.composerController,
    required this.onBack,
    required this.onSend,
  });

  final _Conversation conversation;
  final TextEditingController composerController;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('close-conversation'),
                  tooltip: 'All chats',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        key: Key('conversation-title-${conversation.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 12),
                          SizedBox(width: 3),
                          Text('Encrypted', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Call',
                  onPressed: () {},
                  icon: const Icon(Icons.call_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              itemCount: conversation.messages.length,
              itemBuilder: (context, reverseIndex) {
                final index = conversation.messages.length - reverseIndex - 1;
                return _MessageBubble(message: conversation.messages[index]);
              },
            ),
          ),
          _MessageComposer(
            controller: composerController,
            conversationId: conversation.id,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.sentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.sentByMe
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            height: 1.3,
            color: message.sentByMe
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.conversationId,
    required this.onSend,
  });

  final TextEditingController controller;
  final String conversationId;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Add attachment',
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline),
            ),
            Expanded(
              child: TextField(
                key: Key('message-composer-$conversationId'),
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key('send-message-$conversationId'),
              tooltip: 'Send',
              onPressed: onSend,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    this.diameter = 46,
    this.backgroundColor,
  });

  final String initials;
  final double diameter;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: diameter * 0.34,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.surface,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _Conversation {
  _Conversation({
    required this.id,
    required this.name,
    required this.initials,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.messages,
  });

  final String id;
  final String name;
  final String initials;
  String preview;
  final String time;
  int unreadCount;
  final List<_ChatMessage> messages;
}

final class _ChatMessage {
  const _ChatMessage({required this.body, required this.sentByMe});

  final String body;
  final bool sentByMe;
}

List<_Conversation> _mockConversations() => [
  _Conversation(
    id: 'maya',
    name: 'Maya',
    initials: 'MA',
    preview: 'That works for me. See you then.',
    time: '10:36',
    unreadCount: 0,
    messages: [
      const _ChatMessage(
        body: 'Are we still on for the call later?',
        sentByMe: false,
      ),
      const _ChatMessage(body: 'Yes, 7pm works for me.', sentByMe: true),
      const _ChatMessage(
        body: 'Great. I will send the notes before then.',
        sentByMe: false,
      ),
      const _ChatMessage(body: 'Perfect, talk soon.', sentByMe: true),
    ],
  ),
  _Conversation(
    id: 'kai',
    name: 'Kai',
    initials: 'KA',
    preview: 'Can you send me the updated file?',
    time: '10:34',
    unreadCount: 2,
    messages: [
      const _ChatMessage(
        body: 'Can you send me the updated file?',
        sentByMe: false,
      ),
      const _ChatMessage(
        body: 'Sure. I am making one final change.',
        sentByMe: true,
      ),
      const _ChatMessage(body: 'No rush!', sentByMe: false),
    ],
  ),
  _Conversation(
    id: 'family',
    name: 'Family',
    initials: 'FA',
    preview: 'Dinner is at seven.',
    time: '09:12',
    unreadCount: 1,
    messages: [
      const _ChatMessage(body: 'Dinner is at seven.', sentByMe: false),
      const _ChatMessage(body: 'I will be there.', sentByMe: true),
    ],
  ),
  _Conversation(
    id: 'book-club',
    name: 'Book Club',
    initials: 'BC',
    preview: 'Next meeting is on Thursday.',
    time: 'Yesterday',
    unreadCount: 4,
    messages: [
      const _ChatMessage(body: 'Next meeting is on Thursday.', sentByMe: false),
      const _ChatMessage(body: 'Looking forward to it.', sentByMe: true),
    ],
  ),
  _Conversation(
    id: 'samir',
    name: 'Samir',
    initials: 'SA',
    preview: 'Thanks!',
    time: 'Monday',
    unreadCount: 0,
    messages: [
      const _ChatMessage(body: 'Here are the links.', sentByMe: true),
      const _ChatMessage(body: 'Thanks!', sentByMe: false),
    ],
  ),
];

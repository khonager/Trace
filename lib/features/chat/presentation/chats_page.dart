import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const double _overviewHeaderHeight = 88;
const double _conversationRowHeight = 92;
const double _chatRailWidth = 64;
const double _chatPeekWidth = 28;
const double _desktopSplitBreakpoint = 900;

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
  bool _desktopListCollapsed = false;
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

  void _toggleDesktopList() {
    setState(() => _desktopListCollapsed = !_desktopListCollapsed);
  }

  Widget _buildDesktopWorkspace(BuildContext context, double width) {
    final listWidth = (width * 0.36).clamp(340.0, 430.0);
    final visibleListWidth = _desktopListCollapsed ? 0.0 : listWidth;

    return Row(
      key: const Key('desktop-chat-workspace'),
      children: [
        AnimatedContainer(
          key: const Key('desktop-chat-list-container'),
          width: visibleListWidth,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: listWidth,
            maxWidth: listWidth,
            child: SizedBox(
              width: listWidth,
              child: _ChatOverview(
                conversations: _conversations,
                activeIndex: _activeConversation,
                transitionProgress: 0,
                avatarPromotion: 0,
                transitionTravel: 1,
                scrollController: _overviewScrollController,
                onOpen: _selectConversation,
                highlightActive: true,
              ),
            ),
          ),
        ),
        if (!_desktopListCollapsed)
          VerticalDivider(
            key: const Key('desktop-pane-divider'),
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline,
          ),
        Expanded(
          child: SizedBox.expand(
            key: const Key('desktop-conversation-pane'),
            child: _FocusedChatWorkspace(
              conversations: _conversations,
              activeIndex: _activeConversation,
              composerController: _composerController,
              onBack: _closeConversation,
              onSend: _sendMessage,
              showBackButton: false,
              onToggleList: _toggleDesktopList,
              listVisible: !_desktopListCollapsed,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _desktopSplitBreakpoint) {
          return _buildDesktopWorkspace(context, width);
        }

        final initialWorkspaceLeft = width - _chatRailWidth - _chatPeekWidth;
        final overviewCardWidth = width - _chatPeekWidth;
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
              final conversationLeft =
                  _chatRailWidth + initialWorkspaceLeft * (1 - progress);
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
                      width: overviewCardWidth,
                      child: _ChatOverview(
                        conversations: _conversations,
                        activeIndex: _activeConversation,
                        transitionProgress: progress,
                        avatarPromotion: _avatarPromotion.value,
                        transitionTravel: initialWorkspaceLeft,
                        scrollController: _overviewScrollController,
                        onOpen: _openConversation,
                      ),
                    ),
                    Positioned(
                      left: conversationLeft,
                      top: 0,
                      bottom: 0,
                      width: width - _chatRailWidth,
                      child: _FocusedChatWorkspace(
                        conversations: _conversations,
                        activeIndex: _activeConversation,
                        composerController: _composerController,
                        onBack: _closeConversation,
                        onSend: _sendMessage,
                      ),
                    ),
                    if (progress > 0 || _avatarPromotion.value > 0)
                      Positioned(
                        key: const Key('selected-avatar-foreground'),
                        left: _selectedAvatarLeft(
                          overviewWidth: overviewCardWidth,
                          overviewLeft: overviewLeft,
                          transitionProgress: progress,
                          transitionTravel: initialWorkspaceLeft,
                        ),
                        top: _lerp(
                          _overviewHeaderHeight +
                              _activeConversation * _conversationRowHeight +
                              (_conversationRowHeight - 50) / 2 -
                              scrollOffset,
                          10,
                          Curves.easeOutCubic.transform(_avatarPromotion.value),
                        ),
                        width: 50,
                        child: _ConversationAvatar(
                          key: Key(
                            'rail-${_conversations[_activeConversation].id}',
                          ),
                          conversation: _conversations[_activeConversation],
                          selected: true,
                          onTap: () => _onRailTap(_activeConversation),
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
    required this.activeIndex,
    required this.transitionProgress,
    required this.avatarPromotion,
    required this.transitionTravel,
    required this.scrollController,
    required this.onOpen,
    this.highlightActive = false,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final double transitionProgress;
  final double avatarPromotion;
  final double transitionTravel;
  final ScrollController scrollController;
  final ValueChanged<int> onOpen;
  final bool highlightActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _overviewHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, _chatRailWidth + 8, 8),
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
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: () {},
                    icon: const Icon(Icons.edit_square),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                    ),
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
                final delayedProgress = _delayedSelectedProgress(
                  transitionProgress,
                );
                final selectedLag =
                    transitionTravel * (transitionProgress - delayedProgress);
                return Transform.translate(
                  offset: index == activeIndex
                      ? Offset(selectedLag, 0)
                      : Offset.zero,
                  child: _ConversationRow(
                    key: Key('conversation-row-$index'),
                    conversation: conversation,
                    selected:
                        index == activeIndex &&
                        (highlightActive || transitionProgress > 0.02),
                    avatarVisible:
                        index != activeIndex ||
                        (transitionProgress == 0 && avatarPromotion == 0),
                    onTap: () => onOpen(index),
                  ),
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
    required this.selected,
    required this.avatarVisible,
    required this.onTap,
  });

  final _Conversation conversation;
  final bool selected;
  final bool avatarVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 0.5,
              shadowColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.32),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          conversation.time,
                          key: Key('conversation-time-${conversation.id}'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              conversation.name,
                              key: Key('conversation-name-${conversation.id}'),
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              conversation.preview,
                              key: Key(
                                'conversation-preview-${conversation.id}',
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: _chatRailWidth + 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (avatarVisible)
          Positioned(
            right: 7,
            top: (_conversationRowHeight - 50) / 2,
            width: 50,
            child: _ConversationAvatar(
              key: Key('rail-${conversation.id}'),
              conversation: conversation,
              selected: selected,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _FocusedChatWorkspace extends StatelessWidget {
  const _FocusedChatWorkspace({
    required this.conversations,
    required this.activeIndex,
    required this.composerController,
    required this.onBack,
    required this.onSend,
    this.showBackButton = true,
    this.onToggleList,
    this.listVisible = true,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final TextEditingController composerController;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final bool showBackButton;
  final VoidCallback? onToggleList;
  final bool listVisible;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _ConversationView(
          key: Key('conversation-view-${conversations[activeIndex].id}'),
          conversation: conversations[activeIndex],
          composerController: composerController,
          onBack: onBack,
          onSend: onSend,
          showBackButton: showBackButton,
          onToggleList: onToggleList,
          listVisible: listVisible,
        ),
      ),
    );
  }
}

double _lerp(double start, double end, double progress) =>
    start + (end - start) * progress;

double _delayedSelectedProgress(double progress) =>
    ((progress - 0.14) / 0.86).clamp(0.0, 1.0);

double _selectedAvatarLeft({
  required double overviewWidth,
  required double overviewLeft,
  required double transitionProgress,
  required double transitionTravel,
}) {
  final selectedLag =
      transitionTravel *
      (transitionProgress - _delayedSelectedProgress(transitionProgress));
  return overviewLeft + selectedLag + overviewWidth - 57;
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    super.key,
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
                  key: Key('profile-avatar-${conversation.id}'),
                  initials: conversation.initials,
                  imageAsset: conversation.profileAsset,
                  diameter: selected ? 42 : 40,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
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
    required this.showBackButton,
    required this.onToggleList,
    required this.listVisible,
  });

  final _Conversation conversation;
  final TextEditingController composerController;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final bool showBackButton;
  final VoidCallback? onToggleList;
  final bool listVisible;

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
                if (showBackButton)
                  IconButton(
                    key: const Key('close-conversation'),
                    tooltip: 'All chats',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  IconButton(
                    key: const Key('desktop-chat-list-toggle'),
                    tooltip: listVisible ? 'Hide chat list' : 'Show chat list',
                    onPressed: onToggleList,
                    icon: Icon(
                      listVisible
                          ? Icons.menu_open_rounded
                          : Icons.menu_rounded,
                    ),
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ConversationBackground(conversation: conversation),
                ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: conversation.messages.length,
                  itemBuilder: (context, reverseIndex) {
                    final index =
                        conversation.messages.length - reverseIndex - 1;
                    return _MessageBubble(
                      message: conversation.messages[index],
                    );
                  },
                ),
              ],
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

class _ConversationBackground extends StatelessWidget {
  const _ConversationBackground({required this.conversation});

  final _Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final profileAsset = conversation.profileAsset;
    if (profileAsset == null) {
      return ColoredBox(
        key: Key('conversation-background-${conversation.id}'),
        color: Theme.of(context).colorScheme.surface,
      );
    }

    return ClipRect(
      key: Key('conversation-background-${conversation.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Color.alphaBlend(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48),
              Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
          ),
          Opacity(
            opacity: 0.88,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              child: Transform.scale(
                scale: 1.42,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    1.27545,
                    -0.25025,
                    -0.0252,
                    0,
                    0,
                    -0.07455,
                    1.09975,
                    -0.0252,
                    0,
                    0,
                    -0.07455,
                    -0.25025,
                    1.3248,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Image.asset(
                      profileAsset,
                      key: Key(
                        'conversation-background-image-${conversation.id}',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      cacheWidth: 8,
                      cacheHeight: 8,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
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
          border: Border.all(
            color: message.sentByMe
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.32)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
    super.key,
    required this.initials,
    this.imageAsset,
    this.diameter = 46,
    this.backgroundColor,
  });

  final String initials;
  final String? imageAsset;
  final double diameter;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (imageAsset case final asset?) {
      return ClipOval(
        child: Image.asset(
          asset,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

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
    this.profileAsset,
  });

  final String id;
  final String name;
  final String initials;
  String preview;
  final String time;
  int unreadCount;
  final List<_ChatMessage> messages;
  final String? profileAsset;
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
    profileAsset: 'assets/profiles/maya.webp',
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
    profileAsset: 'assets/profiles/kai.webp',
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
    profileAsset: 'assets/profiles/samir.webp',
    preview: 'Thanks!',
    time: 'Monday',
    unreadCount: 0,
    messages: [
      const _ChatMessage(body: 'Here are the links.', sentByMe: true),
      const _ChatMessage(body: 'Thanks!', sentByMe: false),
    ],
  ),
];

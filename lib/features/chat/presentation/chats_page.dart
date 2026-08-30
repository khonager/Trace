import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart';
import 'package:trace/core/matrix/matrix_client_port.dart';

const double _overviewHeaderHeight = 132;
const double _conversationRowHeight = 92;
const double _chatRailWidth = 64;
const double _chatPeekWidth = 28;
const double _desktopSplitBreakpoint = 900;

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key, this.client});

  final MatrixClientPort? client;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with TickerProviderStateMixin {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _overviewScrollController = ScrollController();

  late List<_Conversation> _conversations;
  List<MatrixRoom> _allRooms = const [];
  final Map<String, _Conversation> _conversationCache = {};
  String? _selectedSpaceId;
  List<String> _spaceOrder = const [];
  StreamSubscription<MatrixClientSnapshot>? _clientSubscription;
  final Map<String, MatrixTimelinePort> _timelines = {};
  final Map<String, StreamSubscription<List<MatrixMessage>>>
  _timelineSubscriptions = {};
  final Map<String, String> _drafts = {};
  Timer? _typingStopTimer;
  String? _replyToEventId;
  String? _replyToLabel;
  late final AnimationController _workspaceTransition;
  late final AnimationController _avatarPromotion;
  late final AnimationController _mobileRailCollapse;
  int _activeConversation = 0;
  bool _dragIsActive = false;
  bool _desktopListCollapsed = false;
  bool _backgroundsPrecached = false;
  bool _attachmentBusy = false;
  double _transitionTravel = 1;
  int? _manualBackgroundFromIndex;

  @override
  void initState() {
    super.initState();
    _allRooms = widget.client?.current.rooms ?? const [];
    _spaceOrder = widget.client?.current.spaceOrder ?? const [];
    _conversations = widget.client == null
        ? _mockConversations()
        : _mapRooms(matrixChatRoomsForSpace(_allRooms));
    for (final conversation in _conversations) {
      _conversationCache[conversation.id] = conversation;
    }
    _clientSubscription = widget.client?.snapshots.listen((snapshot) {
      if (!mounted) return;
      _spaceOrder = snapshot.spaceOrder;
      _applyRooms(snapshot.rooms);
    });
    _workspaceTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _avatarPromotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _mobileRailCollapse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_backgroundsPrecached) return;
    _backgroundsPrecached = true;
    for (final conversation in _conversations) {
      final profileAsset = conversation.profileAsset;
      if (profileAsset == null) continue;
      precacheImage(
        ResizeImage(AssetImage(profileAsset), width: 8, height: 8),
        context,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_clientSubscription?.cancel());
    _typingStopTimer?.cancel();
    for (final subscription in _timelineSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final timeline in _timelines.values) {
      unawaited(timeline.close());
    }
    _workspaceTransition.dispose();
    _avatarPromotion.dispose();
    _mobileRailCollapse.dispose();
    _overviewScrollController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _openConversation(int index) async {
    if (_conversations[index].membership == MatrixRoomMembership.invited) {
      await _showInvite(_conversations[index]);
      return;
    }
    _switchComposerTo(index);
    unawaited(_loadTimeline(index));
    await _settleWorkspace(open: true);
  }

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
    if (!mounted) return;
    setState(() {
      if (open) {
        _conversations[_activeConversation].unreadCount = 0;
      } else if (_manualBackgroundFromIndex case final previousIndex?) {
        _activeConversation = previousIndex;
      }
      _manualBackgroundFromIndex = null;
    });
  }

  void _selectConversation(int index) {
    if (_conversations[index].membership == MatrixRoomMembership.invited) {
      unawaited(_showInvite(_conversations[index]));
      return;
    }
    _switchComposerTo(index, clearUnread: true);
    unawaited(_loadTimeline(index));
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
      setState(() {
        _manualBackgroundFromIndex = index == _activeConversation
            ? null
            : _activeConversation;
        _activeConversation = index;
      });
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

  Future<void> _sendMessage() async {
    final body = _composerController.text.trim();
    if (body.isEmpty) return;
    final client = widget.client;
    if (client != null) {
      final roomId = _conversations[_activeConversation].id;
      _typingStopTimer?.cancel();
      unawaited(client.setTyping(roomId, false).catchError((_) {}));
      _drafts.remove(roomId);
      _composerController.clear();
      try {
        await client.sendText(
          roomId: roomId,
          body: body,
          replyToEventId: _replyToEventId,
        );
        setState(() {
          _replyToEventId = null;
          _replyToLabel = null;
        });
      } catch (error) {
        if (!mounted) return;
        _composerController.text = body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message was not sent: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
      return;
    }
    setState(() {
      _conversations[_activeConversation].messages.add(
        _ChatMessage(body: body, sentByMe: true),
      );
      _conversations[_activeConversation].preview = 'You: $body';
    });
    _composerController.clear();
  }

  Future<void> _showMessageActions(_ChatMessage message) async {
    final client = widget.client;
    final eventId = message.eventId;
    if (client == null || eventId == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (message.delivery == MatrixMessageDelivery.failed)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Retry'),
                onTap: () => Navigator.pop(context, 'retry'),
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Text('👍', style: TextStyle(fontSize: 23)),
              title: const Text('React'),
              onTap: () => Navigator.pop(context, 'react'),
            ),
            if (message.sentByMe)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (message.sentByMe)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final roomId = _conversations[_activeConversation].id;
    try {
      switch (action) {
        case 'retry':
          await _timelines[roomId]?.retry(eventId);
        case 'reply':
          setState(() {
            _replyToEventId = eventId;
            _replyToLabel = 'Replying to ${message.senderName ?? 'message'}';
          });
        case 'react':
          await client.react(roomId: roomId, eventId: eventId, emoji: '👍');
        case 'edit':
          final edited = await _askForEdit(message.body);
          if (edited != null) {
            await client.editMessage(
              roomId: roomId,
              eventId: eventId,
              body: edited,
            );
          }
        case 'delete':
          await _timelines[roomId]?.redact(eventId);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message action failed: $error')),
        );
      }
    }
  }

  Future<void> _requestMessageKey(_ChatMessage message) async {
    final eventId = message.eventId;
    if (eventId == null || _conversations.isEmpty) return;
    final roomId = _conversations[_activeConversation].id;
    final timeline = _timelines[roomId];
    if (timeline == null) return;
    try {
      await timeline.requestKey(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Room key requested. Keep another verified Matrix device online.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not request the room key: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<MatrixAttachmentData> _loadAttachment(
    _ChatMessage message, {
    bool thumbnail = false,
  }) {
    final eventId = message.eventId;
    if (eventId == null || _conversations.isEmpty) {
      throw StateError('Attachment is not available.');
    }
    final roomId = _conversations[_activeConversation].id;
    final timeline = _timelines[roomId];
    if (timeline == null) throw StateError('Timeline is not loaded.');
    return timeline.downloadAttachment(eventId, thumbnail: thumbnail);
  }

  Future<Uint8List> _loadMediaThumbnail(Uri uri) {
    final client = widget.client;
    if (client == null) throw StateError('Matrix media is not available.');
    return client.downloadMediaThumbnail(uri);
  }

  Future<void> _saveAttachment(_ChatMessage message) async {
    try {
      final attachment = await _loadAttachment(message);
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save ${attachment.name}',
        fileName: attachment.name,
        bytes: attachment.bytes,
        mimeType: attachment.mimeType,
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${attachment.name} saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save attachment: ${_errorText(error)}'),
        ),
      );
    }
  }

  Future<String?> _askForEdit(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty == true ? null : result;
  }

  void _switchComposerTo(int index, {bool clearUnread = false}) {
    if (_conversations.isNotEmpty) {
      _drafts[_conversations[_activeConversation].id] =
          _composerController.text;
    }
    setState(() {
      _activeConversation = index;
      if (clearUnread) _conversations[index].unreadCount = 0;
      _composerController.text = _drafts[_conversations[index].id] ?? '';
      _composerController.selection = TextSelection.collapsed(
        offset: _composerController.text.length,
      );
    });
  }

  void _composerChanged(String value) {
    if (_conversations.isEmpty) return;
    final roomId = _conversations[_activeConversation].id;
    _drafts[roomId] = value;
    final client = widget.client;
    if (client == null) return;
    _typingStopTimer?.cancel();
    unawaited(
      client.setTyping(roomId, value.trim().isNotEmpty).catchError((_) {}),
    );
    if (value.trim().isNotEmpty) {
      _typingStopTimer = Timer(const Duration(seconds: 4), () {
        unawaited(client.setTyping(roomId, false).catchError((_) {}));
      });
    }
  }

  Future<void> _sendAttachment() async {
    final client = widget.client;
    if (client == null || _attachmentBusy || _conversations.isEmpty) return;
    final file = await FilePicker.pickFile(dialogTitle: 'Add an attachment');
    if (file == null || !mounted) return;
    final roomId = _conversations[_activeConversation].id;
    final fileName = file.name.trim().isEmpty ? 'attachment' : file.name.trim();
    setState(() => _attachmentBusy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('The selected file is empty.');
      await client.sendFile(
        roomId: roomId,
        name: fileName,
        bytes: bytes,
        mimeType: _mimeTypeFor(file.extension),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$fileName sent.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File was not sent: ${_errorText(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _applyRooms(List<MatrixRoom> rooms) {
    _allRooms = rooms;
    final availableSpaceIds = _availableSpaces.map((space) => space.id).toSet();
    if (_selectedSpaceId != null &&
        !availableSpaceIds.contains(_selectedSpaceId)) {
      _selectedSpaceId = null;
    }
    final oldById = _conversationCache;
    final activeId = _conversations.isEmpty
        ? null
        : _conversations[_activeConversation].id;
    final updated = <_Conversation>[];
    for (final room in matrixChatRoomsForSpace(
      rooms,
      spaceId: _selectedSpaceId,
    )) {
      final existing = oldById[room.id];
      if (existing == null) {
        final conversation = _conversationFromRoom(room);
        _conversationCache[room.id] = conversation;
        updated.add(conversation);
      } else {
        existing
          ..name = room.name
          ..initials = _initialsFor(room.name)
          ..preview = room.preview
          ..time = _formatRoomTime(room.timestamp)
          ..unreadCount = room.unreadCount
          ..profileUrl = room.avatarUrl
          ..encrypted = room.encrypted
          ..membership = room.membership;
        existing
          ..isDirect = room.isDirect
          ..isPinned = room.isPinned
          ..pinOrder = room.pinOrder;
        existing.typingLabel = room.typingUsers.isEmpty
            ? null
            : '${room.typingUsers.join(', ')} ${room.typingUsers.length == 1 ? 'is' : 'are'} typing…';
        updated.add(existing);
      }
    }
    setState(() {
      _conversations = updated;
      final activeIndex = activeId == null
          ? -1
          : updated.indexWhere((room) => room.id == activeId);
      _activeConversation = activeIndex < 0 ? 0 : activeIndex;
      _manualBackgroundFromIndex = null;
    });
    if (_conversations.isNotEmpty) {
      unawaited(_loadTimeline(_activeConversation));
    }
  }

  List<MatrixRoom> get _availableSpaces {
    final spaces = _allRooms
        .where(
          (room) =>
              room.isSpace &&
              matrixChatRoomsForSpace(_allRooms, spaceId: room.id).isNotEmpty,
        )
        .toList(growable: true);
    final positions = {
      for (var index = 0; index < _spaceOrder.length; index++)
        _spaceOrder[index]: index,
    };
    spaces.sort((a, b) {
      final aPosition = positions[a.id];
      final bPosition = positions[b.id];
      if (aPosition != null && bPosition != null) {
        return aPosition.compareTo(bPosition);
      }
      if (aPosition != null) return -1;
      if (bPosition != null) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return spaces;
  }

  void _selectSpace(String? spaceId) {
    if (_selectedSpaceId == spaceId) return;
    _selectedSpaceId = spaceId;
    _applyRooms(_allRooms);
  }

  Future<void> _togglePinned(_Conversation conversation) async {
    final client = widget.client;
    if (client == null) return;
    final pinned = !conversation.isPinned;
    final pinnedRooms = _conversations
        .where((room) => room.isPinned)
        .toList(growable: false);
    final order = pinned
        ? ((pinnedRooms
                      .map((room) => room.pinOrder ?? 0)
                      .fold<double>(
                        0,
                        (largest, value) => value > largest ? value : largest,
                      ) +
                  .1)
              .clamp(0.0, 1.0))
        : null;
    try {
      await client.setRoomPinned(conversation.id, pinned: pinned, order: order);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update pin: ${_errorText(error)}')),
      );
    }
  }

  Future<void> _showSpaceOrder() async {
    final client = widget.client;
    if (client == null) return;
    final ordered = _availableSpaces.toList(growable: true);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SpaceOrderSheet(spaces: ordered),
    );
    if (result == null || !mounted) return;
    setState(() => _spaceOrder = result);
    try {
      await client.setSpaceOrder(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save space order: ${_errorText(error)}'),
        ),
      );
    }
  }

  Future<void> _loadTimeline(int index) async {
    final client = widget.client;
    if (client == null || index < 0 || index >= _conversations.length) return;
    final conversation = _conversations[index];
    if (conversation.membership == MatrixRoomMembership.invited) return;
    var timeline = _timelines[conversation.id];
    if (timeline == null) {
      try {
        timeline = await client.openTimeline(conversation.id);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load messages: $error')),
          );
        }
        return;
      }
      _timelines[conversation.id] = timeline;
      _timelineSubscriptions[conversation.id] = timeline.updates.listen(
        (messages) => _applyTimeline(conversation.id, messages),
      );
    }
    _applyTimeline(conversation.id, timeline.current);
    unawaited(client.markRead(conversation.id).catchError((_) {}));
  }

  Future<void> _loadOlder() async {
    if (_conversations.isEmpty) return;
    final roomId = _conversations[_activeConversation].id;
    final timeline = _timelines[roomId];
    if (timeline?.canLoadOlder == true) await timeline!.loadOlder();
  }

  void _applyTimeline(String roomId, List<MatrixMessage> messages) {
    final index = _conversations.indexWhere((room) => room.id == roomId);
    if (index < 0 || !mounted) return;
    setState(() {
      _conversations[index].messages
        ..clear()
        ..addAll(messages.reversed.map(_ChatMessage.fromMatrix));
    });
  }

  List<_Conversation> _mapRooms(List<MatrixRoom> rooms) =>
      rooms.map(_conversationFromRoom).toList(growable: true);

  _Conversation _conversationFromRoom(MatrixRoom room) => _Conversation(
    id: room.id,
    name: room.name,
    initials: _initialsFor(room.name),
    preview: room.preview,
    time: _formatRoomTime(room.timestamp),
    unreadCount: room.unreadCount,
    messages: [],
    profileUrl: room.avatarUrl,
    encrypted: room.encrypted,
    membership: room.membership,
    typingLabel: room.typingUsers.isEmpty
        ? null
        : '${room.typingUsers.join(', ')} ${room.typingUsers.length == 1 ? 'is' : 'are'} typing…',
    isDirect: room.isDirect,
    isPinned: room.isPinned,
    pinOrder: room.pinOrder,
  );

  void _toggleDesktopList() {
    setState(() => _desktopListCollapsed = !_desktopListCollapsed);
  }

  Future<void> _toggleMobileRail() => _mobileRailCollapse.animateTo(
    _mobileRailCollapse.value < 0.5 ? 1 : 0,
    curve: Curves.easeOutCubic,
  );

  Future<void> _showSearch() async {
    final roomId = await showDialog<String>(
      context: context,
      builder: (context) => _RoomSearchDialog(
        conversations: _conversations,
        client: widget.client,
      ),
    );
    if (roomId == null || !mounted) return;
    final index = _conversations.indexWhere((room) => room.id == roomId);
    if (index >= 0) await _openConversation(index);
  }

  Future<void> _showNewChat() async {
    final client = widget.client;
    if (client == null) return;
    final roomId = await showDialog<String>(
      context: context,
      builder: (context) => _NewChatDialog(client: client),
    );
    if (roomId == null || !mounted) return;
    final existing = _conversations.indexWhere((room) => room.id == roomId);
    if (existing >= 0) await _openConversation(existing);
  }

  Future<void> _showInvite(_Conversation conversation) async {
    final client = widget.client;
    if (client == null) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invitation to ${conversation.name}'),
        content: const Text('Would you like to join this Matrix room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (accept == null) return;
    try {
      if (accept) {
        await client.acceptInvite(conversation.id);
      } else {
        await client.declineInvite(conversation.id);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update invitation: $error')),
        );
      }
    }
  }

  Future<void> _leaveCurrentRoom() async {
    final client = widget.client;
    if (client == null || _conversations.isEmpty) return;
    final conversation = _conversations[_activeConversation];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${conversation.name}?'),
        content: const Text(
          'The room will disappear from this device. You may need another invitation to return.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave room'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await client.leaveRoom(conversation.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave the room: $error')),
        );
      }
    }
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
                spaces: _availableSpaces,
                selectedSpaceId: _selectedSpaceId,
                onSpaceChanged: _selectSpace,
                onReorderSpaces: _showSpaceOrder,
                onTogglePinned: _togglePinned,
                activeIndex: _activeConversation,
                transitionProgress: 0,
                avatarPromotion: 0,
                transitionTravel: 1,
                scrollController: _overviewScrollController,
                onOpen: _selectConversation,
                onSearch: _showSearch,
                onNewChat: _showNewChat,
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
              onSend: _sendMessage,
              onAttachment: _sendAttachment,
              onComposerChanged: _composerChanged,
              onLoadOlder: _loadOlder,
              onMessageLongPress: _showMessageActions,
              onRequestMessageKey: _requestMessageKey,
              onLoadAttachment: _loadAttachment,
              onLoadMediaThumbnail: _loadMediaThumbnail,
              onSaveAttachment: _saveAttachment,
              onTogglePinned: widget.client == null
                  ? null
                  : () => _togglePinned(_conversations[_activeConversation]),
              onLeave: widget.client == null ? null : _leaveCurrentRoom,
              replyLabel: _replyToLabel,
              attachmentBusy: _attachmentBusy,
              onCancelReply: () => setState(() {
                _replyToEventId = null;
                _replyToLabel = null;
              }),
              showMobileRailToggle: false,
              onToggleList: _toggleDesktopList,
              listVisible: !_desktopListCollapsed,
              backgroundCanvasWidth: width,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_conversations.isEmpty) {
      return _EmptyRoomsView(
        snapshot: widget.client?.current,
        onSearch: _showSearch,
        onNewChat: widget.client == null ? null : _showNewChat,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _desktopSplitBreakpoint) {
          return _buildDesktopWorkspace(context, width);
        }

        final initialWorkspaceLeft = width - _chatPeekWidth;
        final overviewCardWidth = width - _chatPeekWidth;

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
              _mobileRailCollapse,
              _overviewScrollController,
            ]),
            builder: (context, _) {
              final progress = _workspaceTransition.value;
              final visibleRailWidth =
                  _chatRailWidth * (1 - _mobileRailCollapse.value);
              final transitionTravel = initialWorkspaceLeft - visibleRailWidth;
              _transitionTravel = transitionTravel;
              final overviewLeft = -transitionTravel * progress;
              final conversationLeft =
                  initialWorkspaceLeft - transitionTravel * progress;
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
                        spaces: _availableSpaces,
                        selectedSpaceId: _selectedSpaceId,
                        onSpaceChanged: _selectSpace,
                        onReorderSpaces: _showSpaceOrder,
                        onTogglePinned: _togglePinned,
                        activeIndex: _activeConversation,
                        transitionProgress: progress,
                        avatarPromotion: _avatarPromotion.value,
                        transitionTravel: transitionTravel,
                        scrollController: _overviewScrollController,
                        onOpen: _openConversation,
                        onSearch: _showSearch,
                        onNewChat: _showNewChat,
                      ),
                    ),
                    Positioned(
                      key: const Key('mobile-conversation-pane'),
                      left: conversationLeft,
                      top: 0,
                      bottom: 0,
                      width: width - visibleRailWidth,
                      child: _FocusedChatWorkspace(
                        conversations: _conversations,
                        activeIndex: _activeConversation,
                        composerController: _composerController,
                        onSend: _sendMessage,
                        onAttachment: _sendAttachment,
                        onComposerChanged: _composerChanged,
                        onLoadOlder: _loadOlder,
                        onMessageLongPress: _showMessageActions,
                        onRequestMessageKey: _requestMessageKey,
                        onLoadAttachment: _loadAttachment,
                        onLoadMediaThumbnail: _loadMediaThumbnail,
                        onSaveAttachment: _saveAttachment,
                        onTogglePinned: widget.client == null
                            ? null
                            : () => _togglePinned(
                                _conversations[_activeConversation],
                              ),
                        onLeave: widget.client == null
                            ? null
                            : _leaveCurrentRoom,
                        replyLabel: _replyToLabel,
                        attachmentBusy: _attachmentBusy,
                        onCancelReply: () => setState(() {
                          _replyToEventId = null;
                          _replyToLabel = null;
                        }),
                        onToggleMobileRail: _toggleMobileRail,
                        mobileRailVisible: _mobileRailCollapse.value < 0.5,
                        backgroundCanvasWidth: width,
                        backgroundPageLeft: conversationLeft,
                        swipeBackgroundFrom: _manualBackgroundFromIndex == null
                            ? null
                            : _conversations[_manualBackgroundFromIndex!],
                        swipeBackgroundProgress:
                            _manualBackgroundFromIndex == null
                            ? null
                            : progress,
                      ),
                    ),
                    if (progress > 0 || _avatarPromotion.value > 0)
                      Positioned(
                        key: const Key('selected-avatar-foreground'),
                        left: _selectedAvatarLeft(
                          overviewWidth: overviewCardWidth,
                          overviewLeft: overviewLeft,
                          transitionProgress: progress,
                          transitionTravel: transitionTravel,
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
    required this.spaces,
    required this.selectedSpaceId,
    required this.onSpaceChanged,
    required this.onReorderSpaces,
    required this.onTogglePinned,
    required this.activeIndex,
    required this.transitionProgress,
    required this.avatarPromotion,
    required this.transitionTravel,
    required this.scrollController,
    required this.onOpen,
    required this.onSearch,
    required this.onNewChat,
    this.highlightActive = false,
  });

  final List<_Conversation> conversations;
  final List<MatrixRoom> spaces;
  final String? selectedSpaceId;
  final ValueChanged<String?> onSpaceChanged;
  final VoidCallback onReorderSpaces;
  final ValueChanged<_Conversation> onTogglePinned;
  final int activeIndex;
  final double transitionProgress;
  final double avatarPromotion;
  final double transitionTravel;
  final ScrollController scrollController;
  final ValueChanged<int> onOpen;
  final VoidCallback onSearch;
  final VoidCallback onNewChat;
  final bool highlightActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('chat-overview'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _overviewHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chats',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        key: const Key('search-chats'),
                        tooltip: 'Search',
                        onPressed: onSearch,
                        icon: const Icon(Icons.search),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        key: const Key('new-chat'),
                        tooltip: 'New chat',
                        onPressed: onNewChat,
                        icon: const Icon(Icons.edit_square),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      key: const Key('space-context-dock'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          key: const Key('all-chats-context'),
                          selected: selectedSpaceId == null,
                          onSelected: (_) => onSpaceChanged(null),
                          avatar: const Icon(Icons.forum_outlined, size: 18),
                          label: const Text('All'),
                        ),
                        for (final space in spaces) ...[
                          const SizedBox(width: 6),
                          ChoiceChip(
                            key: Key('space-context-${space.id}'),
                            selected: selectedSpaceId == space.id,
                            onSelected: (_) => onSpaceChanged(space.id),
                            avatar: const Icon(
                              Icons.workspaces_outline,
                              size: 18,
                            ),
                            label: Text(space.name),
                          ),
                        ],
                        if (spaces.isNotEmpty) ...[
                          const SizedBox(width: 2),
                          OutlinedButton.icon(
                            key: const Key('reorder-spaces'),
                            onPressed: onReorderSpaces,
                            icon: const Icon(Icons.reorder, size: 18),
                            label: const Text('Order'),
                          ),
                        ],
                      ],
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
                    onLongPress: () => onTogglePinned(conversation),
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
    this.onLongPress,
  });

  final _Conversation conversation;
  final bool selected;
  final bool avatarVisible;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
                onLongPress: onLongPress,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (conversation.isPinned) ...[
                                  const Icon(Icons.push_pin, size: 14),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    conversation.name,
                                    key: Key(
                                      'conversation-name-${conversation.id}',
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
    required this.onSend,
    required this.onAttachment,
    required this.onComposerChanged,
    required this.onLoadOlder,
    required this.onMessageLongPress,
    required this.onRequestMessageKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.onSaveAttachment,
    required this.onTogglePinned,
    required this.onLeave,
    required this.replyLabel,
    required this.attachmentBusy,
    required this.onCancelReply,
    this.showMobileRailToggle = true,
    this.onToggleMobileRail,
    this.mobileRailVisible = true,
    this.onToggleList,
    this.listVisible = true,
    required this.backgroundCanvasWidth,
    this.backgroundPageLeft,
    this.swipeBackgroundFrom,
    this.swipeBackgroundProgress,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final TextEditingController composerController;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final ValueChanged<String> onComposerChanged;
  final AsyncCallback onLoadOlder;
  final ValueChanged<_ChatMessage> onMessageLongPress;
  final ValueChanged<_ChatMessage> onRequestMessageKey;
  final Future<MatrixAttachmentData> Function(_ChatMessage, {bool thumbnail})
  onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final ValueChanged<_ChatMessage> onSaveAttachment;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onLeave;
  final String? replyLabel;
  final bool attachmentBusy;
  final VoidCallback onCancelReply;
  final bool showMobileRailToggle;
  final VoidCallback? onToggleMobileRail;
  final bool mobileRailVisible;
  final VoidCallback? onToggleList;
  final bool listVisible;
  final double backgroundCanvasWidth;
  final double? backgroundPageLeft;
  final _Conversation? swipeBackgroundFrom;
  final double? swipeBackgroundProgress;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: _ConversationView(
        conversation: conversations[activeIndex],
        composerController: composerController,
        onSend: onSend,
        onAttachment: onAttachment,
        onComposerChanged: onComposerChanged,
        onLoadOlder: onLoadOlder,
        onMessageLongPress: onMessageLongPress,
        onRequestMessageKey: onRequestMessageKey,
        onLoadAttachment: onLoadAttachment,
        onLoadMediaThumbnail: onLoadMediaThumbnail,
        onSaveAttachment: onSaveAttachment,
        onTogglePinned: onTogglePinned,
        onLeave: onLeave,
        replyLabel: replyLabel,
        attachmentBusy: attachmentBusy,
        onCancelReply: onCancelReply,
        showMobileRailToggle: showMobileRailToggle,
        onToggleMobileRail: onToggleMobileRail,
        mobileRailVisible: mobileRailVisible,
        onToggleList: onToggleList,
        listVisible: listVisible,
        backgroundCanvasWidth: backgroundCanvasWidth,
        backgroundPageLeft: backgroundPageLeft,
        swipeBackgroundFrom: swipeBackgroundFrom,
        swipeBackgroundProgress: swipeBackgroundProgress,
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
                  imageUrl: conversation.profileUrl,
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
    required this.conversation,
    required this.composerController,
    required this.onSend,
    required this.onAttachment,
    required this.onComposerChanged,
    required this.onLoadOlder,
    required this.onMessageLongPress,
    required this.onRequestMessageKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.onSaveAttachment,
    required this.onTogglePinned,
    required this.onLeave,
    required this.replyLabel,
    required this.attachmentBusy,
    required this.onCancelReply,
    required this.showMobileRailToggle,
    required this.onToggleMobileRail,
    required this.mobileRailVisible,
    required this.onToggleList,
    required this.listVisible,
    required this.backgroundCanvasWidth,
    required this.backgroundPageLeft,
    required this.swipeBackgroundFrom,
    required this.swipeBackgroundProgress,
  });

  final _Conversation conversation;
  final TextEditingController composerController;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final ValueChanged<String> onComposerChanged;
  final AsyncCallback onLoadOlder;
  final ValueChanged<_ChatMessage> onMessageLongPress;
  final ValueChanged<_ChatMessage> onRequestMessageKey;
  final Future<MatrixAttachmentData> Function(_ChatMessage, {bool thumbnail})
  onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final ValueChanged<_ChatMessage> onSaveAttachment;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onLeave;
  final String? replyLabel;
  final bool attachmentBusy;
  final VoidCallback onCancelReply;
  final bool showMobileRailToggle;
  final VoidCallback? onToggleMobileRail;
  final bool mobileRailVisible;
  final VoidCallback? onToggleList;
  final bool listVisible;
  final double backgroundCanvasWidth;
  final double? backgroundPageLeft;
  final _Conversation? swipeBackgroundFrom;
  final double? swipeBackgroundProgress;

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
                if (showMobileRailToggle)
                  IconButton(
                    key: const Key('mobile-chat-rail-toggle'),
                    tooltip: mobileRailVisible
                        ? 'Hide chat tabs'
                        : 'Show chat tabs',
                    onPressed: onToggleMobileRail,
                    icon: Icon(
                      mobileRailVisible
                          ? Icons.menu_open_rounded
                          : Icons.menu_rounded,
                    ),
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
                      Row(
                        children: [
                          Icon(
                            conversation.encrypted
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            conversation.typingLabel ??
                                (conversation.encrypted
                                    ? 'Encrypted'
                                    : 'Not encrypted'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onTogglePinned != null || onLeave != null)
                  PopupMenuButton<String>(
                    key: Key('room-actions-${conversation.id}'),
                    tooltip: 'Room actions',
                    onSelected: (value) {
                      if (value == 'pin') onTogglePinned?.call();
                      if (value == 'leave') onLeave!();
                    },
                    itemBuilder: (context) => [
                      if (onTogglePinned != null)
                        PopupMenuItem(
                          value: 'pin',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              conversation.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin,
                            ),
                            title: Text(
                              conversation.isPinned ? 'Unpin chat' : 'Pin chat',
                            ),
                          ),
                        ),
                      if (onLeave != null)
                        const PopupMenuItem(
                          value: 'leave',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.logout),
                            title: Text('Leave room'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (swipeBackgroundFrom case final previousConversation?)
                  _ManualBackgroundReveal(
                    previousConversation: previousConversation,
                    conversation: conversation,
                    progress: swipeBackgroundProgress ?? 0,
                    canvasWidth: backgroundCanvasWidth,
                    pageLeft: backgroundPageLeft,
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    reverseDuration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _ConversationBackground(
                      key: ValueKey(
                        'conversation-background-transition-${conversation.id}',
                      ),
                      conversation: conversation,
                      canvasWidth: backgroundCanvasWidth,
                      pageLeft: backgroundPageLeft,
                    ),
                  ),
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final metrics = notification.metrics;
                    if (metrics.pixels >= metrics.maxScrollExtent - 120) {
                      unawaited(onLoadOlder());
                    }
                    return false;
                  },
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    itemCount: conversation.messages.length,
                    itemBuilder: (context, reverseIndex) {
                      final index =
                          conversation.messages.length - reverseIndex - 1;
                      return _MessageBubble(
                        message: conversation.messages[index],
                        showSenderIdentity: !conversation.isDirect,
                        onLongPress: () =>
                            onMessageLongPress(conversation.messages[index]),
                        onRequestKey: () =>
                            onRequestMessageKey(conversation.messages[index]),
                        onLoadAttachment: () => onLoadAttachment(
                          conversation.messages[index],
                          thumbnail: true,
                        ),
                        onLoadMediaThumbnail: onLoadMediaThumbnail,
                        onSaveAttachment: () =>
                            onSaveAttachment(conversation.messages[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _MessageComposer(
            controller: composerController,
            conversationId: conversation.id,
            onSend: onSend,
            onAttachment: onAttachment,
            onChanged: onComposerChanged,
            replyLabel: replyLabel,
            attachmentBusy: attachmentBusy,
            onCancelReply: onCancelReply,
          ),
        ],
      ),
    );
  }
}

class _ManualBackgroundReveal extends StatelessWidget {
  const _ManualBackgroundReveal({
    required this.previousConversation,
    required this.conversation,
    required this.progress,
    required this.canvasWidth,
    required this.pageLeft,
  });

  final _Conversation previousConversation;
  final _Conversation conversation;
  final double progress;
  final double canvasWidth;
  final double? pageLeft;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ConversationBackground(
          conversation: previousConversation,
          canvasWidth: canvasWidth,
          pageLeft: pageLeft,
        ),
        Opacity(
          key: Key('manual-background-reveal-${conversation.id}'),
          opacity: progress.clamp(0.0, 1.0),
          child: _ConversationBackground(
            conversation: conversation,
            canvasWidth: canvasWidth,
            pageLeft: pageLeft,
          ),
        ),
      ],
    );
  }
}

class _ConversationBackground extends StatelessWidget {
  const _ConversationBackground({
    super.key,
    required this.conversation,
    required this.canvasWidth,
    required this.pageLeft,
  });

  final _Conversation conversation;
  final double canvasWidth;
  final double? pageLeft;

  @override
  Widget build(BuildContext context) {
    final profileAsset = conversation.profileAsset;
    final profileUrl = conversation.profileUrl;
    if (profileAsset == null && profileUrl == null) {
      return ColoredBox(
        key: Key('conversation-background-${conversation.id}'),
        color: Theme.of(context).colorScheme.surface,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoredPageLeft =
            pageLeft ?? (canvasWidth - constraints.maxWidth);
        return ClipRect(
          key: Key('conversation-background-${conversation.id}'),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: canvasWidth,
            maxWidth: canvasWidth,
            minHeight: constraints.maxHeight,
            maxHeight: constraints.maxHeight,
            child: Transform.translate(
              offset: Offset(-anchoredPageLeft, 0),
              child: SizedBox(
                key: Key('conversation-background-canvas-${conversation.id}'),
                width: canvasWidth,
                height: constraints.maxHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Color.alphaBlend(
                        Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                    ),
                    Opacity(
                      opacity: 0.88,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 48,
                          sigmaY: 48,
                          tileMode: ui.TileMode.clamp,
                        ),
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
                              child: profileAsset != null
                                  ? Image.asset(
                                      profileAsset,
                                      key: Key(
                                        'conversation-background-image-${conversation.id}',
                                      ),
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      cacheWidth: 8,
                                      cacheHeight: 8,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : Image.network(
                                      profileUrl.toString(),
                                      key: Key(
                                        'conversation-background-image-${conversation.id}',
                                      ),
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      filterQuality: FilterQuality.low,
                                      errorBuilder: (_, _, _) => ColoredBox(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                      ),
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.showSenderIdentity,
    required this.onLongPress,
    required this.onRequestKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.onSaveAttachment,
  });

  final _ChatMessage message;
  final bool showSenderIdentity;
  final VoidCallback onLongPress;
  final VoidCallback onRequestKey;
  final Future<MatrixAttachmentData> Function() onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final VoidCallback onSaveAttachment;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  Future<MatrixAttachmentData>? _image;

  @override
  void initState() {
    super.initState();
    if (widget.message.kind == MatrixMessageKind.image) {
      _image = widget.onLoadAttachment();
    }
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.eventId != widget.message.eventId) {
      _image = widget.message.kind == MatrixMessageKind.image
          ? widget.onLoadAttachment()
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSender =
        widget.showSenderIdentity &&
        !widget.message.sentByMe &&
        !widget.message.isSystem;
    return Align(
      alignment: widget.message.sentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSender) ...[
            _MessageSenderAvatar(
              message: widget.message,
              onLoadMediaThumbnail: widget.onLoadMediaThumbnail,
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: GestureDetector(
              onTap:
                  widget.message.kind == MatrixMessageKind.text ||
                      widget.message.kind == MatrixMessageKind.image
                  ? null
                  : widget.onSaveAttachment,
              onLongPress: widget.onLongPress,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.message.sentByMe
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.message.sentByMe
                        ? Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.32)
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.65),
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
                child: Column(
                  crossAxisAlignment: widget.message.sentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (showSender) ...[
                      Text(
                        widget.message.senderName ?? widget.message.senderId,
                        key: Key(
                          'message-sender-${widget.message.eventId ?? widget.message.senderId}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (widget.message.kind == MatrixMessageKind.image)
                      _ImageAttachment(
                        data: _image!,
                        name:
                            widget.message.attachmentName ??
                            widget.message.body,
                        foreground: widget.message.sentByMe
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.onSurface,
                        onRetry: () => setState(() {
                          _image = widget.onLoadAttachment();
                        }),
                      )
                    else if (widget.message.kind != MatrixMessageKind.text)
                      _FileAttachment(
                        message: widget.message,
                        foreground: widget.message.sentByMe
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.onSurface,
                      )
                    else
                      Text(
                        widget.message.body,
                        style: TextStyle(
                          height: 1.3,
                          fontStyle: widget.message.isSystem
                              ? FontStyle.italic
                              : null,
                          color: widget.message.sentByMe
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    if (widget.message.isUndecryptable) ...[
                      const SizedBox(height: 6),
                      if (widget.message.canRequestKey)
                        TextButton.icon(
                          key: Key(
                            'request-room-key-${widget.message.eventId}',
                          ),
                          onPressed: widget.onRequestKey,
                          icon: const Icon(Icons.key_outlined, size: 16),
                          label: const Text('Request key'),
                          style: TextButton.styleFrom(
                            foregroundColor: widget.message.sentByMe
                                ? Theme.of(context).colorScheme.surface
                                : Theme.of(context).colorScheme.onSurface,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        )
                      else
                        Text(
                          'Restore encryption recovery to access its room key.',
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.message.sentByMe
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.72)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                    if (widget.message.delivery != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        switch (widget.message.delivery!) {
                          MatrixMessageDelivery.sending => 'Sending…',
                          MatrixMessageDelivery.failed =>
                            'Failed · tap to retry',
                          MatrixMessageDelivery.sent => 'Sent',
                          MatrixMessageDelivery.synced => _formatMessageTime(
                            widget.message.timestamp!,
                          ),
                        },
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.message.sentByMe
                              ? Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.72)
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageSenderAvatar extends StatefulWidget {
  const _MessageSenderAvatar({
    required this.message,
    required this.onLoadMediaThumbnail,
  });

  final _ChatMessage message;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;

  @override
  State<_MessageSenderAvatar> createState() => _MessageSenderAvatarState();
}

class _MessageSenderAvatarState extends State<_MessageSenderAvatar> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MessageSenderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.senderAvatarUrl != widget.message.senderAvatarUrl) {
      _load();
    }
  }

  void _load() {
    final uri = widget.message.senderAvatarUrl;
    _image = uri == null ? null : widget.onLoadMediaThumbnail(uri);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _InitialsFallback(
      initials: _initialsFor(
        widget.message.senderName ?? widget.message.senderId,
      ),
      diameter: 30,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
    return Padding(
      key: Key(
        'message-sender-avatar-${widget.message.eventId ?? widget.message.senderId}',
      ),
      padding: const EdgeInsets.only(top: 2),
      child: _image == null
          ? fallback
          : FutureBuilder<Uint8List>(
              future: _image,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return fallback;
                return ClipOval(
                  child: Image.memory(
                    snapshot.data!,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                );
              },
            ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.data,
    required this.name,
    required this.foreground,
    required this.onRetry,
  });

  final Future<MatrixAttachmentData> data;
  final String name;
  final Color foreground;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatrixAttachmentData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  snapshot.data!.bytes,
                  key: Key('message-image-$name'),
                  fit: BoxFit.cover,
                  width: 272,
                  errorBuilder: (_, _, _) => _AttachmentError(
                    foreground: foreground,
                    onRetry: onRetry,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          );
        }
        if (snapshot.hasError) {
          return _AttachmentError(foreground: foreground, onRetry: onRetry);
        }
        return const SizedBox(
          width: 272,
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _AttachmentError extends StatelessWidget {
  const _AttachmentError({required this.foreground, required this.onRetry});

  final Color foreground;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 272,
    height: 96,
    child: Center(
      child: TextButton.icon(
        onPressed: onRetry,
        style: TextButton.styleFrom(foregroundColor: foreground),
        icon: const Icon(Icons.refresh),
        label: const Text('Load image again'),
      ),
    ),
  );
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.message, required this.foreground});

  final _ChatMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(switch (message.kind) {
        MatrixMessageKind.video => Icons.videocam_outlined,
        MatrixMessageKind.audio => Icons.audio_file_outlined,
        _ => Icons.insert_drive_file_outlined,
      }, color: foreground),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.attachmentName ?? message.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              [
                if (message.attachmentSize case final size?)
                  _formatFileSize(size),
                'Tap to save',
              ].join(' · '),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.conversationId,
    required this.onSend,
    required this.onAttachment,
    required this.onChanged,
    required this.replyLabel,
    required this.attachmentBusy,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final String conversationId;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final ValueChanged<String> onChanged;
  final String? replyLabel;
  final bool attachmentBusy;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyLabel case final label?)
              Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label)),
                  IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Add attachment',
                  onPressed: attachmentBusy ? null : onAttachment,
                  icon: attachmentBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    key: Key('message-composer-$conversationId'),
                    controller: controller,
                    onChanged: onChanged,
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
          ],
        ),
      ),
    );
  }
}

class _SpaceOrderSheet extends StatefulWidget {
  const _SpaceOrderSheet({required this.spaces});

  final List<MatrixRoom> spaces;

  @override
  State<_SpaceOrderSheet> createState() => _SpaceOrderSheetState();
}

class _SpaceOrderSheetState extends State<_SpaceOrderSheet> {
  late final List<MatrixRoom> _spaces = widget.spaces.toList(growable: true);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .62,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order spaces',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _spaces.map((space) => space.id).toList(growable: false),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'This personal order follows your Matrix account across Trace devices.',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _spaces.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  _spaces.insert(newIndex, _spaces.removeAt(oldIndex));
                });
              },
              itemBuilder: (context, index) {
                final space = _spaces[index];
                return ListTile(
                  key: ValueKey(space.id),
                  leading: const Icon(Icons.workspaces_outline),
                  title: Text(space.name),
                  trailing: const Icon(Icons.drag_handle),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    super.key,
    required this.initials,
    this.imageAsset,
    this.imageUrl,
    this.diameter = 46,
    this.backgroundColor,
  });

  final String initials;
  final String? imageAsset;
  final Uri? imageUrl;
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

    if (imageUrl case final url?) {
      return ClipOval(
        child: Image.network(
          url.toString(),
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => _InitialsFallback(
            initials: initials,
            diameter: diameter,
            backgroundColor: backgroundColor,
          ),
        ),
      );
    }

    return _InitialsFallback(
      initials: initials,
      diameter: diameter,
      backgroundColor: backgroundColor,
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.initials,
    required this.diameter,
    required this.backgroundColor,
  });

  final String initials;
  final double diameter;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      color:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(fontSize: diameter * 0.34, fontWeight: FontWeight.w600),
    ),
  );
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

class _EmptyRoomsView extends StatelessWidget {
  const _EmptyRoomsView({
    required this.snapshot,
    required this.onSearch,
    required this.onNewChat,
  });

  final MatrixClientSnapshot? snapshot;
  final VoidCallback onSearch;
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final reconnecting = {
      MatrixConnectionPhase.syncing,
      MatrixConnectionPhase.reconnecting,
    }.contains(snapshot?.phase);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(reconnecting ? Icons.sync : Icons.forum_outlined, size: 42),
              const SizedBox(height: 18),
              Text(
                reconnecting ? 'Syncing your rooms…' : 'No conversations yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                snapshot?.error ??
                    'Start a private conversation or create Saved Messages.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (onNewChat != null)
                FilledButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.edit_square),
                  label: const Text('New chat'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomSearchDialog extends StatefulWidget {
  const _RoomSearchDialog({required this.conversations, required this.client});

  final List<_Conversation> conversations;
  final MatrixClientPort? client;

  @override
  State<_RoomSearchDialog> createState() => _RoomSearchDialogState();
}

class _RoomSearchDialogState extends State<_RoomSearchDialog> {
  final _controller = TextEditingController();
  List<MatrixUser> _people = const [];
  List<MatrixMessageSearchResult> _messageResults = const [];
  Timer? _debounce;
  bool _searchingPeople = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    final client = widget.client;
    if (client == null || value.trim().length < 2) {
      setState(() {
        _people = const [];
        _messageResults = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      setState(() => _searchingPeople = true);
      try {
        List<MatrixUser> people = const [];
        List<MatrixMessageSearchResult> messages = const [];
        try {
          messages = await client.searchMessages(value.trim());
        } catch (_) {
          // Cached room and preview matches below remain available.
        }
        try {
          people = await client.searchUsers(value.trim());
        } catch (_) {
          // Local message search remains usable while directory search is off.
        }
        if (mounted && _controller.text.trim() == value.trim()) {
          setState(() {
            _people = people;
            _messageResults = messages;
          });
        }
      } catch (_) {
        // Local room/message results remain usable while offline.
      } finally {
        if (mounted) setState(() => _searchingPeople = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final rooms = query.isEmpty
        ? widget.conversations
        : widget.conversations.where((room) {
            return room.name.toLowerCase().contains(query) ||
                room.preview.toLowerCase().contains(query) ||
                room.messages.any(
                  (message) => message.body.toLowerCase().contains(query),
                );
          }).toList();
    return AlertDialog(
      title: const Text('Search'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          children: [
            TextField(
              key: const Key('chat-search-field'),
              controller: _controller,
              autofocus: true,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: 'Rooms, cached messages, or people',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchingPeople
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  if (rooms.isNotEmpty) ...[
                    const _SearchSectionLabel('Rooms and messages'),
                    for (final room in rooms)
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(room.name),
                        subtitle: Text(
                          room.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, room.id),
                      ),
                  ],
                  if (_people.isNotEmpty) ...[
                    const _SearchSectionLabel('People'),
                    for (final person in _people)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(person.displayName ?? person.userId),
                        subtitle: Text(person.userId),
                        onTap: () async {
                          final roomId = await widget.client!.startDirectChat(
                            person.userId,
                          );
                          if (context.mounted) Navigator.pop(context, roomId);
                        },
                      ),
                  ],
                  if (_messageResults.isNotEmpty) ...[
                    const _SearchSectionLabel('Cached messages'),
                    for (final result in _messageResults)
                      ListTile(
                        leading: const Icon(Icons.message_outlined),
                        title: Text(result.roomName),
                        subtitle: Text(
                          '${result.senderName}: ${result.body}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, result.roomId),
                      ),
                  ],
                  if (query.isNotEmpty &&
                      rooms.isEmpty &&
                      _people.isEmpty &&
                      _messageResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No matches in cached messages. Keep typing to search the homeserver directory.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  const _SearchSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog({required this.client});

  final MatrixClientPort client;

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _controller = TextEditingController();
  List<MatrixUser> _results = const [];
  Timer? _debounce;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final results = await widget.client.searchUsers(value.trim());
        if (mounted && _controller.text.trim() == value.trim()) {
          setState(() => _results = results);
        }
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  Future<void> _savedMessages() async {
    await _run(() => widget.client.createSavedMessagesRoom());
  }

  Future<void> _newGroup() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New private group'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name?.trim().isNotEmpty == true) {
      await _run(() => widget.client.createGroup(name: name!.trim()));
    }
  }

  Future<void> _joinRoom() async {
    final roomController = TextEditingController();
    final room = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a Matrix room'),
        content: TextField(
          controller: roomController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Room address or ID',
            hintText: '#room:example.org',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, roomController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    roomController.dispose();
    if (room?.trim().isNotEmpty == true) {
      await _run(() => widget.client.joinRoom(room!.trim()));
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomId = await action();
      if (mounted) Navigator.pop(context, roomId);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New chat'),
    content: SizedBox(
      width: 460,
      height: 430,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _savedMessages,
                icon: const Icon(Icons.bookmark_outline),
                label: const Text('Saved Messages'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _newGroup,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Private group'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _joinRoom,
                icon: const Icon(Icons.login),
                label: const Text('Join room'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('new-chat-user-search'),
            controller: _controller,
            onChanged: _search,
            decoration: const InputDecoration(
              labelText: 'Find a Matrix user',
              hintText: '@name:server.org',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final person = _results[index];
                return ListTile(
                  title: Text(person.displayName ?? person.userId),
                  subtitle: Text(person.userId),
                  onTap: _busy
                      ? null
                      : () => _run(
                          () => widget.client.startDirectChat(person.userId),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

String _initialsFor(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _formatRoomTime(DateTime timestamp) {
  if (timestamp.millisecondsSinceEpoch == 0) return '';
  final now = DateTime.now();
  final local = timestamp.toLocal();
  if (now.year == local.year &&
      now.month == local.month &&
      now.day == local.day) {
    return _formatMessageTime(local);
  }
  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${local.day}.${local.month}.${local.year == now.year ? '' : local.year}';
}

String _formatMessageTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(kib < 10 ? 1 : 0)} KB';
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(mib < 10 ? 1 : 0)} MB';
}

String _errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

String _mimeTypeFor(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  'mp3' => 'audio/mpeg',
  'm4a' => 'audio/mp4',
  'ogg' || 'opus' => 'audio/ogg',
  'wav' => 'audio/wav',
  'mp4' => 'video/mp4',
  'pdf' => 'application/pdf',
  'txt' => 'text/plain',
  'json' => 'application/json',
  _ => 'application/octet-stream',
};

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
    this.profileUrl,
    this.encrypted = true,
    this.membership = MatrixRoomMembership.joined,
    this.typingLabel,
    this.isDirect = false,
    this.isPinned = false,
    this.pinOrder,
  });

  final String id;
  String name;
  String initials;
  String preview;
  String time;
  int unreadCount;
  final List<_ChatMessage> messages;
  final String? profileAsset;
  Uri? profileUrl;
  bool encrypted;
  MatrixRoomMembership membership;
  String? typingLabel;
  bool isDirect;
  bool isPinned;
  double? pinOrder;
}

final class _ChatMessage {
  const _ChatMessage({
    required this.body,
    required this.sentByMe,
    this.eventId,
    this.senderName,
    this.senderId = '',
    this.senderAvatarUrl,
    this.timestamp,
    this.delivery,
    this.isSystem = false,
    this.isUndecryptable = false,
    this.canRequestKey = false,
    this.kind = MatrixMessageKind.text,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSize,
  });

  factory _ChatMessage.fromMatrix(MatrixMessage message) => _ChatMessage(
    body: message.body,
    sentByMe: message.sentByMe,
    eventId: message.eventId,
    senderName: message.senderName,
    senderId: message.senderId,
    senderAvatarUrl: message.senderAvatarUrl,
    timestamp: message.timestamp,
    delivery: message.delivery,
    isSystem: message.isSystem || message.isUndecryptable,
    isUndecryptable: message.isUndecryptable,
    canRequestKey: message.canRequestKey,
    kind: message.kind,
    attachmentName: message.attachmentName,
    attachmentMimeType: message.attachmentMimeType,
    attachmentSize: message.attachmentSize,
  );

  final String body;
  final bool sentByMe;
  final String? eventId;
  final String? senderName;
  final String senderId;
  final Uri? senderAvatarUrl;
  final DateTime? timestamp;
  final MatrixMessageDelivery? delivery;
  final bool isSystem;
  final bool isUndecryptable;
  final bool canRequestKey;
  final MatrixMessageKind kind;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSize;
}

List<_Conversation> _mockConversations() => [
  _Conversation(
    id: 'maya',
    isDirect: true,
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
    isDirect: true,
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
      const _ChatMessage(
        body: 'Dinner is at seven.',
        sentByMe: false,
        senderId: '@mom:example.org',
        senderName: 'Mom',
      ),
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
    isDirect: true,
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

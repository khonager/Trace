import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyboardInsertedContent, rootBundle;
import 'package:trace/core/matrix/matrix_client_port.dart';
import 'package:trace/features/chat/application/attachment_picker.dart';
import 'package:trace/features/chat/application/composer_actions.dart';
import 'package:trace/features/chat/application/configured_media_search_client.dart';
import 'package:trace/features/chat/application/media_search.dart';
import 'package:url_launcher/url_launcher.dart';

const double _overviewHeaderHeight = 132;
const double _conversationRowHeight = 92;
const double _chatRailWidth = 48;
const double _chatAvatarRightInset = 16;
const double _chatPeekWidth = 28;
const double _desktopSplitBreakpoint = 900;
const String _peopleContextId = 'trace:people';
const List<String> _commonReactions = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
  '🎉',
  '🔥',
];

enum _ReactionPickerAction { custom }

typedef _OpenProfilePicture =
    void Function({required String name, Uri? mediaUri, String? asset});

class ChatsPage extends StatefulWidget {
  const ChatsPage({
    super.key,
    this.client,
    this.saveAttachment,
    this.openLink,
    this.pickAttachment,
    this.mediaSearch,
    this.composerActionPinStore,
  });

  final MatrixClientPort? client;
  final Future<String?> Function(MatrixAttachmentData attachment)?
  saveAttachment;
  final Future<bool> Function(Uri uri)? openLink;
  final Future<ChatAttachment?> Function()? pickAttachment;
  final MediaSearchPort? mediaSearch;
  final ComposerActionPinStore? composerActionPinStore;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with TickerProviderStateMixin {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _overviewScrollController = ScrollController();

  late List<_Conversation> _conversations;
  List<MatrixRoom> _allRooms = const [];
  final Map<String, _Conversation> _conversationCache = {};
  String? _selectedContextId;
  List<String> _spaceOrder = const [];
  StreamSubscription<MatrixClientSnapshot>? _clientSubscription;
  final Map<String, MatrixTimelinePort> _timelines = {};
  final Map<String, GlobalKey<_MessageBubbleState>> _messageKeys = {};
  final Map<String, StreamSubscription<List<MatrixMessage>>>
  _timelineSubscriptions = {};
  final Map<String, String> _drafts = {};
  final Map<Uri, Uint8List> _mediaThumbnailBytes = {};
  final Map<Uri, Future<Uint8List>> _mediaThumbnailLoads = {};
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
  late final MediaSearchPort _mediaSearch;
  late final ComposerActionPinStore _composerActionPinStore;
  List<ComposerAction> _pinnedComposerActions = const [];
  double _transitionTravel = 1;
  int? _manualBackgroundFromIndex;

  @override
  void initState() {
    super.initState();
    _mediaSearch = widget.mediaSearch ?? ConfiguredMediaSearchClient();
    _composerActionPinStore =
        widget.composerActionPinStore ??
        SharedPreferencesComposerActionPinStore();
    unawaited(_loadPinnedComposerActions());
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

  Future<void> _loadPinnedComposerActions() async {
    try {
      final actions = await _composerActionPinStore.load();
      if (mounted) setState(() => _pinnedComposerActions = actions);
    } catch (_) {
      // Pin persistence is a convenience; the composer remains usable if the
      // platform preference store is temporarily unavailable.
    }
  }

  void _toggleComposerActionPinned(ComposerAction action) {
    final updated = _pinnedComposerActions.toList(growable: true);
    if (updated.remove(action)) {
      // Removed above.
    } else {
      updated.add(action);
    }
    setState(() => _pinnedComposerActions = List.unmodifiable(updated));
    unawaited(_composerActionPinStore.save(updated).catchError((_) {}));
  }

  void _runComposerAction(ComposerAction action) {
    switch (action) {
      case ComposerAction.attachFile:
        unawaited(_sendAttachment());
      case ComposerAction.gifSearch:
        unawaited(_showMediaSearch(MediaSearchKind.gif));
      case ComposerAction.stickerSearch:
        unawaited(_showMediaSearch(MediaSearchKind.sticker));
    }
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
    final previousIndex = open ? null : _manualBackgroundFromIndex;
    if (previousIndex != null) {
      _switchComposerTo(previousIndex);
    }
    if (!mounted) return;
    setState(() {
      if (open) {
        _conversations[_activeConversation].unreadCount = 0;
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
      final previousIndex = _activeConversation;
      if (index == previousIndex) {
        setState(() => _manualBackgroundFromIndex = null);
      } else {
        _switchComposerTo(index);
        setState(() => _manualBackgroundFromIndex = previousIndex);
      }
      unawaited(_loadTimeline(index));
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
            if (message.timestamp != null) ...[
              Padding(
                key: const Key('message-details-timestamp'),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${_formatMessageDate(message.timestamp!)} · ${_formatMessageTime(message.timestamp!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
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
              leading: Text(
                message.reactionByMe ?? '👍',
                style: const TextStyle(fontSize: 23),
              ),
              title: Text(
                message.reactionByMe == null ? 'React' : 'Change reaction',
              ),
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
          final emoji = await _chooseReaction(message.reactionByMe);
          if (emoji == null || !mounted) return;
          final timeline = _timelines[roomId];
          if (timeline == null) return;
          await timeline.toggleReaction(eventId, emoji);
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

  Future<String?> _chooseReaction(String? selectedEmoji) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a reaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final emoji in _commonReactions)
                    ChoiceChip(
                      key: Key('reaction-$emoji'),
                      label: Text(emoji, style: const TextStyle(fontSize: 24)),
                      selected: selectedEmoji == emoji,
                      tooltip: selectedEmoji == emoji
                          ? 'Remove $emoji reaction'
                          : 'React with $emoji',
                      onSelected: (_) => Navigator.pop(context, emoji),
                    ),
                  if (selectedEmoji != null &&
                      !_commonReactions.contains(selectedEmoji))
                    ChoiceChip(
                      key: const Key('current-custom-reaction'),
                      label: Text(
                        selectedEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      selected: true,
                      tooltip: 'Remove $selectedEmoji reaction',
                      onSelected: (_) => Navigator.pop(context, selectedEmoji),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('custom-reaction'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Use another emoji'),
                subtitle: const Text('Paste or type any emoji'),
                onTap: () =>
                    Navigator.pop(context, _ReactionPickerAction.custom),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == _ReactionPickerAction.custom) {
      return mounted ? _askForCustomReaction() : null;
    }
    return choice as String?;
  }

  Future<String?> _askForCustomReaction() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _CustomReactionDialog(),
    );
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
            'Room key requested. Approve it on another Trace device, or keep a verified Matrix device online.',
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
  }) async {
    final eventId = message.eventId;
    if (eventId == null || _conversations.isEmpty) {
      throw StateError('Attachment is not available.');
    }
    final roomId = _conversations[_activeConversation].id;
    final timeline = _timelines[roomId];
    if (timeline == null) throw StateError('Timeline is not loaded.');
    if (!thumbnail) return timeline.downloadAttachment(eventId);
    try {
      return await timeline.downloadAttachment(eventId, thumbnail: true);
    } catch (_) {
      // Pending Matrix image events are inserted before the SDK has generated
      // their thumbnail. The original bytes are already in the local send
      // cache, so use them immediately instead of showing a retry error.
      return timeline.downloadAttachment(eventId);
    }
  }

  Future<Uint8List> _loadMediaThumbnail(Uri uri) {
    final cached = _mediaThumbnailBytes[uri];
    if (cached != null) return Future.value(cached);
    final pending = _mediaThumbnailLoads[uri];
    if (pending != null) return pending;
    final client = widget.client;
    if (client == null) throw StateError('Matrix media is not available.');
    final load = client
        .downloadMediaThumbnail(uri)
        .then(
          (bytes) {
            _mediaThumbnailBytes[uri] = bytes;
            _mediaThumbnailLoads.remove(uri);
            return bytes;
          },
          onError: (Object error, StackTrace stackTrace) {
            _mediaThumbnailLoads.remove(uri);
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
    _mediaThumbnailLoads[uri] = load;
    return load;
  }

  Uint8List? _cachedMediaThumbnail(Uri uri) => _mediaThumbnailBytes[uri];

  Future<void> _showProfilePicture({
    required String name,
    Uri? mediaUri,
    String? asset,
  }) async {
    if (mediaUri == null && asset == null) return;
    final image = mediaUri != null
        ? widget.client!.downloadMedia(mediaUri)
        : rootBundle
              .load(asset!)
              .then(
                (data) => data.buffer.asUint8List(
                  data.offsetInBytes,
                  data.lengthInBytes,
                ),
              );
    await showDialog<void>(
      context: context,
      builder: (context) => _ProfilePictureDialog(
        name: name,
        image: image,
        onDownload: (bytes) => _saveProfilePicture(name, bytes),
      ),
    );
  }

  Future<void> _saveProfilePicture(String name, Uint8List bytes) async {
    try {
      final format = _profileImageFormat(bytes);
      final safeName = name
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final fileName =
          '${safeName.isEmpty ? 'profile' : safeName}-profile.${format.extension}';
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save $name profile picture',
        fileName: fileName,
        bytes: bytes,
        mimeType: format.mimeType,
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$fileName saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile picture: ${_errorText(error)}'),
        ),
      );
    }
  }

  Future<void> _saveAttachment(_ChatMessage message) async {
    try {
      final attachment = await _loadAttachment(message);
      await _saveAttachmentData(attachment);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save attachment: ${_errorText(error)}'),
        ),
      );
    }
  }

  Future<void> _saveAttachmentData(MatrixAttachmentData attachment) async {
    try {
      final saveAttachment = widget.saveAttachment;
      final saved = saveAttachment == null
          ? await FilePicker.saveFile(
              dialogTitle: 'Save ${attachment.name}',
              fileName: attachment.name,
              bytes: attachment.bytes,
              mimeType: attachment.mimeType,
            )
          : await saveAttachment(attachment);
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

  Future<void> _showImage(_ChatMessage message) async {
    final image = _loadAttachment(message);
    await showDialog<void>(
      context: context,
      builder: (context) => _ReceivedImageDialog(
        name: message.attachmentName ?? message.body,
        image: image,
        onDownload: _saveAttachmentData,
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    try {
      final openLink = widget.openLink;
      final opened = openLink == null
          ? await launchUrl(uri, mode: LaunchMode.externalApplication)
          : await openLink(uri);
      if (!opened) throw Exception('No application could open this link.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: ${_errorText(error)}')),
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
    setState(() => _attachmentBusy = true);
    var fileSelected = false;
    try {
      final file = await (widget.pickAttachment ?? pickChatAttachment)();
      if (file == null || !mounted) return;
      fileSelected = true;
      final roomId = _conversations[_activeConversation].id;
      final fileName = file.name.trim().isEmpty
          ? 'attachment'
          : file.name.trim();
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
          SnackBar(
            content: Text(
              '${fileSelected ? 'File was not sent' : 'File picker could not open'}: '
              '${_errorText(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _sendKeyboardContent(KeyboardInsertedContent content) async {
    final client = widget.client;
    if (client == null || _attachmentBusy || _conversations.isEmpty) return;
    setState(() => _attachmentBusy = true);
    try {
      final bytes = content.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('The keyboard did not provide readable media bytes.');
      }
      final mimeType = content.mimeType.toLowerCase();
      final extension = switch (mimeType) {
        'image/gif' => 'gif',
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        'image/webp' => 'webp',
        _ => throw Exception('Unsupported keyboard media type: $mimeType.'),
      };
      final roomId = _conversations[_activeConversation].id;
      await client.sendFile(
        roomId: roomId,
        name: 'keyboard-${DateTime.now().millisecondsSinceEpoch}.$extension',
        bytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Keyboard media sent.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Keyboard media was not sent: ${_errorText(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _showMediaSearch(MediaSearchKind kind) async {
    final client = widget.client;
    if (client == null || _attachmentBusy || _conversations.isEmpty) return;
    final result = await showModalBottomSheet<MediaSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _MediaSearchSheet(kind: kind, mediaSearch: _mediaSearch),
    );
    if (result == null || !mounted) return;
    setState(() => _attachmentBusy = true);
    try {
      final downloaded = await _mediaSearch.download(result);
      if (!mounted) return;
      final roomId = _conversations[_activeConversation].id;
      await client.sendFile(
        roomId: roomId,
        name: _mediaFileName(result, downloaded.mimeType),
        bytes: downloaded.bytes,
        mimeType: downloaded.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${kind == MediaSearchKind.gif ? 'GIF' : 'Sticker'} sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Media was not sent: ${_errorText(error)}')),
      );
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  String _mediaFileName(MediaSearchResult result, String mimeType) {
    final safeTitle = result.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final extension = switch (mimeType) {
      'image/gif' => 'gif',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'video/mp4' => 'mp4',
      _ => 'bin',
    };
    return '${safeTitle.isEmpty ? result.id : safeTitle}.$extension';
  }

  void _applyRooms(List<MatrixRoom> rooms) {
    _allRooms = rooms;
    final availableSpaceIds = _availableSpaces.map((space) => space.id).toSet();
    if (_selectedContextId != null &&
        _selectedContextId != _peopleContextId &&
        !availableSpaceIds.contains(_selectedContextId)) {
      _selectedContextId = null;
    }
    final oldById = _conversationCache;
    final activeId = _conversations.isEmpty
        ? null
        : _conversations[_activeConversation].id;
    final updated = <_Conversation>[];
    final visibleRooms = _selectedContextId == _peopleContextId
        ? matrixDirectChatRooms(rooms)
        : matrixChatRoomsForSpace(rooms, spaceId: _selectedContextId);
    for (final room in visibleRooms) {
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
          ..profileMediaUri = room.avatarMediaUri
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

  void _selectContext(String? contextId) {
    if (_selectedContextId == contextId) return;
    _selectedContextId = contextId;
    if (widget.client == null) {
      final conversations = _conversationCache.values.toList(growable: true);
      setState(() {
        _conversations = contextId == _peopleContextId
            ? conversations
                  .where((conversation) => conversation.isDirect)
                  .toList(growable: true)
            : conversations;
        _activeConversation = 0;
        _manualBackgroundFromIndex = null;
      });
      return;
    }
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
      final visibleEventIds = _conversations
          .expand((conversation) => conversation.messages)
          .map((message) => message.eventId)
          .whereType<String>()
          .toSet();
      _messageKeys.removeWhere(
        (eventId, _) => !visibleEventIds.contains(eventId),
      );
    });
  }

  GlobalKey<_MessageBubbleState> _messageKeyFor(String eventId) => _messageKeys
      .putIfAbsent(eventId, () => GlobalKey(debugLabel: 'message-$eventId'));

  void _openReply(String eventId) {
    final targetContext = _messageKeys[eventId]?.currentContext;
    if (targetContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The original message is not loaded yet.'),
        ),
      );
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: .5,
      ),
    );
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
    profileMediaUri: room.avatarMediaUri,
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
                selectedContextId: _selectedContextId,
                onContextChanged: _selectContext,
                onReorderSpaces: _showSpaceOrder,
                onTogglePinned: _togglePinned,
                activeIndex: _activeConversation,
                transitionProgress: 0,
                avatarPromotion: 0,
                transitionTravel: 1,
                scrollController: _overviewScrollController,
                onOpen: _selectConversation,
                onLoadMediaThumbnail: _loadMediaThumbnail,
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
              onComposerAction: _runComposerAction,
              pinnedComposerActions: _pinnedComposerActions,
              onToggleComposerActionPinned: _toggleComposerActionPinned,
              onKeyboardContent: _sendKeyboardContent,
              onComposerChanged: _composerChanged,
              onLoadOlder: _loadOlder,
              onMessageLongPress: _showMessageActions,
              onRequestMessageKey: _requestMessageKey,
              onLoadAttachment: _loadAttachment,
              onLoadMediaThumbnail: _loadMediaThumbnail,
              cachedMediaThumbnail: _cachedMediaThumbnail,
              onOpenProfilePicture: _showProfilePicture,
              onSaveAttachment: _saveAttachment,
              onOpenImage: _showImage,
              onOpenLink: _openLink,
              messageKeyFor: _messageKeyFor,
              onOpenReply: _openReply,
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
      if (_selectedContextId != null) {
        return _ChatOverview(
          conversations: const [],
          spaces: _availableSpaces,
          selectedContextId: _selectedContextId,
          onContextChanged: _selectContext,
          onReorderSpaces: _showSpaceOrder,
          onTogglePinned: _togglePinned,
          activeIndex: 0,
          transitionProgress: 0,
          avatarPromotion: 0,
          transitionTravel: 1,
          scrollController: _overviewScrollController,
          onOpen: (_) {},
          onLoadMediaThumbnail: _loadMediaThumbnail,
          onSearch: _showSearch,
          onNewChat: _showNewChat,
        );
      }
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
              final promotedAvatarVisible =
                  (progress > 0 || _avatarPromotion.value > 0) &&
                  _avatarPromotion.value < 1;
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
                        selectedContextId: _selectedContextId,
                        onContextChanged: _selectContext,
                        onReorderSpaces: _showSpaceOrder,
                        onTogglePinned: _togglePinned,
                        activeIndex: _activeConversation,
                        transitionProgress: progress,
                        avatarPromotion: _avatarPromotion.value,
                        transitionTravel: transitionTravel,
                        scrollController: _overviewScrollController,
                        onOpen: _openConversation,
                        onLoadMediaThumbnail: _loadMediaThumbnail,
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
                        onComposerAction: _runComposerAction,
                        pinnedComposerActions: _pinnedComposerActions,
                        onToggleComposerActionPinned:
                            _toggleComposerActionPinned,
                        onKeyboardContent: _sendKeyboardContent,
                        onComposerChanged: _composerChanged,
                        onLoadOlder: _loadOlder,
                        onMessageLongPress: _showMessageActions,
                        onRequestMessageKey: _requestMessageKey,
                        onLoadAttachment: _loadAttachment,
                        onLoadMediaThumbnail: _loadMediaThumbnail,
                        cachedMediaThumbnail: _cachedMediaThumbnail,
                        onOpenProfilePicture: _showProfilePicture,
                        onSaveAttachment: _saveAttachment,
                        onOpenImage: _showImage,
                        onOpenLink: _openLink,
                        messageKeyFor: _messageKeyFor,
                        onOpenReply: _openReply,
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
                        showProfileAvatar: !promotedAvatarVisible,
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
                    if (promotedAvatarVisible)
                      Positioned.fill(
                        key: const Key('selected-avatar-foreground'),
                        child: ClipPath(
                          clipper: _PromotedAvatarClipper(
                            conversationLeft: conversationLeft,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: _promotedAvatarLeft(
                                  cardLeft: _selectedAvatarLeft(
                                    overviewWidth: overviewCardWidth,
                                    overviewLeft: overviewLeft,
                                    transitionProgress: progress,
                                    transitionTravel: transitionTravel,
                                  ),
                                  conversationLeft: conversationLeft,
                                  promotion: _avatarPromotion.value,
                                ),
                                top: _lerp(
                                  _overviewHeaderHeight +
                                      _activeConversation *
                                          _conversationRowHeight +
                                      (_conversationRowHeight - 50) / 2 -
                                      scrollOffset,
                                  7,
                                  Curves.easeOutCubic.transform(
                                    _avatarPromotion.value,
                                  ),
                                ),
                                width: 50,
                                height: 50,
                                child: _PromotedConversationAvatar(
                                  key: Key(
                                    'rail-${_conversations[_activeConversation].id}',
                                  ),
                                  conversation:
                                      _conversations[_activeConversation],
                                  progress: Curves.easeOutCubic.transform(
                                    _avatarPromotion.value,
                                  ),
                                  onLoadMediaThumbnail: _loadMediaThumbnail,
                                  onTap: () => _onRailTap(_activeConversation),
                                ),
                              ),
                            ],
                          ),
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
    required this.selectedContextId,
    required this.onContextChanged,
    required this.onReorderSpaces,
    required this.onTogglePinned,
    required this.activeIndex,
    required this.transitionProgress,
    required this.avatarPromotion,
    required this.transitionTravel,
    required this.scrollController,
    required this.onOpen,
    required this.onLoadMediaThumbnail,
    required this.onSearch,
    required this.onNewChat,
    this.highlightActive = false,
  });

  final List<_Conversation> conversations;
  final List<MatrixRoom> spaces;
  final String? selectedContextId;
  final ValueChanged<String?> onContextChanged;
  final VoidCallback onReorderSpaces;
  final ValueChanged<_Conversation> onTogglePinned;
  final int activeIndex;
  final double transitionProgress;
  final double avatarPromotion;
  final double transitionTravel;
  final ScrollController scrollController;
  final ValueChanged<int> onOpen;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
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
                      if (spaces.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          key: const Key('reorder-spaces'),
                          tooltip: 'Order spaces',
                          onPressed: onReorderSpaces,
                          icon: const Icon(Icons.reorder_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                        ),
                      ],
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
                        _ChatContextTab(
                          key: const Key('all-chats-context'),
                          selected: selectedContextId == null,
                          onTap: () => onContextChanged(null),
                          label: 'All',
                        ),
                        const SizedBox(width: 20),
                        _ChatContextTab(
                          key: const Key('people-chats-context'),
                          selected: selectedContextId == _peopleContextId,
                          onTap: () => onContextChanged(_peopleContextId),
                          label: 'People',
                        ),
                        for (final space in spaces) ...[
                          const SizedBox(width: 20),
                          _ChatContextTab(
                            key: Key('space-context-${space.id}'),
                            selected: selectedContextId == space.id,
                            onTap: () => onContextChanged(space.id),
                            label: space.name,
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
            child: conversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        selectedContextId == _peopleContextId
                            ? 'No direct chats with people yet.'
                            : 'No chats in this space yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
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
                          transitionTravel *
                          (transitionProgress - delayedProgress);
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
                          onLoadMediaThumbnail: onLoadMediaThumbnail,
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

class _ChatContextTab extends StatelessWidget {
  const _ChatContextTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.selected,
    required this.avatarVisible,
    required this.onLoadMediaThumbnail,
    required this.onTap,
    this.onLongPress,
  });

  final _Conversation conversation;
  final bool selected;
  final bool avatarVisible;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
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
                      const SizedBox(width: 50 + _chatAvatarRightInset + 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (avatarVisible)
          Positioned(
            right: _chatAvatarRightInset,
            top: (_conversationRowHeight - 50) / 2,
            width: 50,
            child: _ConversationAvatar(
              key: Key('rail-${conversation.id}'),
              conversation: conversation,
              selected: selected,
              onLoadMediaThumbnail: onLoadMediaThumbnail,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _CustomReactionDialog extends StatefulWidget {
  const _CustomReactionDialog();

  @override
  State<_CustomReactionDialog> createState() => _CustomReactionDialogState();
}

class _CustomReactionDialogState extends State<_CustomReactionDialog> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    final emoji = _controller.text.trim();
    if (emoji.isNotEmpty) Navigator.pop(context, emoji);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Custom reaction'),
    content: TextField(
      key: const Key('custom-reaction-input'),
      controller: _controller,
      autofocus: true,
      maxLength: 64,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'Emoji',
        helperText: 'One emoji or emoji sequence',
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm-custom-reaction'),
        onPressed: _submit,
        child: const Text('React'),
      ),
    ],
  );
}

class _FocusedChatWorkspace extends StatelessWidget {
  const _FocusedChatWorkspace({
    required this.conversations,
    required this.activeIndex,
    required this.composerController,
    required this.onSend,
    required this.onComposerAction,
    required this.pinnedComposerActions,
    required this.onToggleComposerActionPinned,
    required this.onKeyboardContent,
    required this.onComposerChanged,
    required this.onLoadOlder,
    required this.onMessageLongPress,
    required this.onRequestMessageKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.cachedMediaThumbnail,
    required this.onOpenProfilePicture,
    required this.onSaveAttachment,
    required this.onOpenImage,
    required this.onOpenLink,
    required this.messageKeyFor,
    required this.onOpenReply,
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
    this.showProfileAvatar = true,
    required this.backgroundCanvasWidth,
    this.backgroundPageLeft,
    this.swipeBackgroundFrom,
    this.swipeBackgroundProgress,
  });

  final List<_Conversation> conversations;
  final int activeIndex;
  final TextEditingController composerController;
  final VoidCallback onSend;
  final ValueChanged<ComposerAction> onComposerAction;
  final List<ComposerAction> pinnedComposerActions;
  final ValueChanged<ComposerAction> onToggleComposerActionPinned;
  final ValueChanged<KeyboardInsertedContent> onKeyboardContent;
  final ValueChanged<String> onComposerChanged;
  final AsyncCallback onLoadOlder;
  final ValueChanged<_ChatMessage> onMessageLongPress;
  final ValueChanged<_ChatMessage> onRequestMessageKey;
  final Future<MatrixAttachmentData> Function(_ChatMessage, {bool thumbnail})
  onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final Uint8List? Function(Uri) cachedMediaThumbnail;
  final _OpenProfilePicture onOpenProfilePicture;
  final ValueChanged<_ChatMessage> onSaveAttachment;
  final ValueChanged<_ChatMessage> onOpenImage;
  final ValueChanged<Uri> onOpenLink;
  final GlobalKey<_MessageBubbleState> Function(String) messageKeyFor;
  final ValueChanged<String> onOpenReply;
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
  final bool showProfileAvatar;
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
        onComposerAction: onComposerAction,
        pinnedComposerActions: pinnedComposerActions,
        onToggleComposerActionPinned: onToggleComposerActionPinned,
        onKeyboardContent: onKeyboardContent,
        onComposerChanged: onComposerChanged,
        onLoadOlder: onLoadOlder,
        onMessageLongPress: onMessageLongPress,
        onRequestMessageKey: onRequestMessageKey,
        onLoadAttachment: onLoadAttachment,
        onLoadMediaThumbnail: onLoadMediaThumbnail,
        cachedMediaThumbnail: cachedMediaThumbnail,
        onOpenProfilePicture: onOpenProfilePicture,
        onSaveAttachment: onSaveAttachment,
        onOpenImage: onOpenImage,
        onOpenLink: onOpenLink,
        messageKeyFor: messageKeyFor,
        onOpenReply: onOpenReply,
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
        showProfileAvatar: showProfileAvatar,
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
  return overviewLeft +
      selectedLag +
      overviewWidth -
      50 -
      _chatAvatarRightInset;
}

double _promotedAvatarLeft({
  required double cardLeft,
  required double conversationLeft,
  required double promotion,
}) => _lerp(
  cardLeft,
  // The header image starts 58 px into the conversation pane. The promoted
  // avatar keeps a 50 px layout box, so its 34 px final image is inset 8 px.
  conversationLeft + 50,
  Curves.easeOutCubic.transform(promotion),
);

class _PromotedAvatarClipper extends CustomClipper<Path> {
  const _PromotedAvatarClipper({required this.conversationLeft});

  final double conversationLeft;

  @override
  Path getClip(Size size) => Path()
    ..addRect(Rect.fromLTRB(0, _overviewHeaderHeight, size.width, size.height))
    ..addRect(
      Rect.fromLTRB(
        conversationLeft.clamp(0.0, size.width),
        0,
        size.width,
        _overviewHeaderHeight,
      ),
    );

  @override
  bool shouldReclip(_PromotedAvatarClipper oldClipper) =>
      oldClipper.conversationLeft != conversationLeft;
}

class _PromotedConversationAvatar extends StatelessWidget {
  const _PromotedConversationAvatar({
    super.key,
    required this.conversation,
    required this.progress,
    required this.onLoadMediaThumbnail,
    required this.onTap,
  });

  final _Conversation conversation;
  final double progress;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderDiameter = _lerp(48, 34, progress);
    final imageDiameter = _lerp(42, 34, progress);
    return Semantics(
      button: true,
      label: 'Open ${conversation.name}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: borderDiameter,
              height: borderDiameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: progress < 1
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 1 - progress),
                        width: 2,
                      )
                    : null,
                shape: BoxShape.circle,
              ),
              child: _InitialsAvatar(
                initials: conversation.initials,
                imageAsset: conversation.profileAsset,
                imageUrl: conversation.profileUrl,
                mediaUri: conversation.profileMediaUri,
                onLoadMediaThumbnail: onLoadMediaThumbnail,
                diameter: imageDiameter,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
              ),
            ),
            if (conversation.unreadCount > 0 && progress < 1)
              Positioned(
                right: 3,
                bottom: 2,
                child: Opacity(
                  opacity: 1 - progress,
                  child: _UnreadBadge(count: conversation.unreadCount),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onLoadMediaThumbnail,
    required this.onTap,
  });

  final _Conversation conversation;
  final bool selected;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
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
                  mediaUri: conversation.profileMediaUri,
                  onLoadMediaThumbnail: onLoadMediaThumbnail,
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
    required this.onComposerAction,
    required this.pinnedComposerActions,
    required this.onToggleComposerActionPinned,
    required this.onKeyboardContent,
    required this.onComposerChanged,
    required this.onLoadOlder,
    required this.onMessageLongPress,
    required this.onRequestMessageKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.cachedMediaThumbnail,
    required this.onOpenProfilePicture,
    required this.onSaveAttachment,
    required this.onOpenImage,
    required this.onOpenLink,
    required this.messageKeyFor,
    required this.onOpenReply,
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
    required this.showProfileAvatar,
    required this.backgroundCanvasWidth,
    required this.backgroundPageLeft,
    required this.swipeBackgroundFrom,
    required this.swipeBackgroundProgress,
  });

  final _Conversation conversation;
  final TextEditingController composerController;
  final VoidCallback onSend;
  final ValueChanged<ComposerAction> onComposerAction;
  final List<ComposerAction> pinnedComposerActions;
  final ValueChanged<ComposerAction> onToggleComposerActionPinned;
  final ValueChanged<KeyboardInsertedContent> onKeyboardContent;
  final ValueChanged<String> onComposerChanged;
  final AsyncCallback onLoadOlder;
  final ValueChanged<_ChatMessage> onMessageLongPress;
  final ValueChanged<_ChatMessage> onRequestMessageKey;
  final Future<MatrixAttachmentData> Function(_ChatMessage, {bool thumbnail})
  onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final Uint8List? Function(Uri) cachedMediaThumbnail;
  final _OpenProfilePicture onOpenProfilePicture;
  final ValueChanged<_ChatMessage> onSaveAttachment;
  final ValueChanged<_ChatMessage> onOpenImage;
  final ValueChanged<Uri> onOpenLink;
  final GlobalKey<_MessageBubbleState> Function(String) messageKeyFor;
  final ValueChanged<String> onOpenReply;
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
  final bool showProfileAvatar;
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
                const SizedBox(width: 2),
                IgnorePointer(
                  ignoring: !showProfileAvatar,
                  child: Opacity(
                    opacity: showProfileAvatar ? 1 : 0,
                    child: Tooltip(
                      message: 'Open profile picture',
                      child: InkWell(
                        key: Key('open-profile-picture-${conversation.id}'),
                        onTap: () => onOpenProfilePicture(
                          name: conversation.name,
                          mediaUri: conversation.profileMediaUri,
                          asset: conversation.profileAsset,
                        ),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _InitialsAvatar(
                            initials: conversation.initials,
                            imageAsset: conversation.profileAsset,
                            imageUrl: conversation.profileUrl,
                            mediaUri: conversation.profileMediaUri,
                            onLoadMediaThumbnail: onLoadMediaThumbnail,
                            diameter: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                    onLoadMediaThumbnail: onLoadMediaThumbnail,
                    cachedMediaThumbnail: cachedMediaThumbnail,
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
                      onLoadMediaThumbnail: onLoadMediaThumbnail,
                      cachedMediaThumbnail: cachedMediaThumbnail,
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
                      final message = conversation.messages[index];
                      final replyToEventId = message.replyToEventId;
                      final previousTimestamp = index == 0
                          ? null
                          : conversation.messages[index - 1].timestamp;
                      final showDate =
                          message.timestamp != null &&
                          (previousTimestamp == null ||
                              !_isSameLocalDay(
                                previousTimestamp,
                                message.timestamp!,
                              ));
                      return Column(
                        children: [
                          if (showDate)
                            _MessageDateSeparator(
                              timestamp: message.timestamp!,
                            ),
                          _MessageBubble(
                            key: message.eventId == null
                                ? null
                                : messageKeyFor(message.eventId!),
                            message: message,
                            showTimestamp: _isToday(message.timestamp),
                            showSenderIdentity: !conversation.isDirect,
                            onLongPress: () => onMessageLongPress(message),
                            onRequestKey: () => onRequestMessageKey(message),
                            onLoadAttachment: () =>
                                onLoadAttachment(message, thumbnail: true),
                            onLoadMediaThumbnail: onLoadMediaThumbnail,
                            onOpenProfilePicture: onOpenProfilePicture,
                            onSaveAttachment: () => onSaveAttachment(message),
                            onOpenImage: () => onOpenImage(message),
                            onOpenLink: onOpenLink,
                            onOpenReply: replyToEventId != null
                                ? () => onOpenReply(replyToEventId)
                                : null,
                          ),
                        ],
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
            onComposerAction: onComposerAction,
            pinnedActions: pinnedComposerActions,
            onTogglePinned: onToggleComposerActionPinned,
            onKeyboardContent: onKeyboardContent,
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
    required this.onLoadMediaThumbnail,
    required this.cachedMediaThumbnail,
  });

  final _Conversation previousConversation;
  final _Conversation conversation;
  final double progress;
  final double canvasWidth;
  final double? pageLeft;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final Uint8List? Function(Uri) cachedMediaThumbnail;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ConversationBackground(
          conversation: previousConversation,
          canvasWidth: canvasWidth,
          pageLeft: pageLeft,
          onLoadMediaThumbnail: onLoadMediaThumbnail,
          cachedMediaThumbnail: cachedMediaThumbnail,
        ),
        Opacity(
          key: Key('manual-background-reveal-${conversation.id}'),
          opacity: progress.clamp(0.0, 1.0),
          child: _ConversationBackground(
            conversation: conversation,
            canvasWidth: canvasWidth,
            pageLeft: pageLeft,
            onLoadMediaThumbnail: onLoadMediaThumbnail,
            cachedMediaThumbnail: cachedMediaThumbnail,
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
    required this.onLoadMediaThumbnail,
    required this.cachedMediaThumbnail,
  });

  final _Conversation conversation;
  final double canvasWidth;
  final double? pageLeft;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final Uint8List? Function(Uri) cachedMediaThumbnail;

  @override
  Widget build(BuildContext context) {
    final profileAsset = conversation.profileAsset;
    final profileUrl = conversation.profileUrl;
    final profileMediaUri = conversation.profileMediaUri;
    if (profileAsset == null && profileMediaUri == null && profileUrl == null) {
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
                                  : profileMediaUri != null
                                  ? _MatrixMediaBackgroundImage(
                                      key: ValueKey(
                                        'matrix-background-${conversation.id}',
                                      ),
                                      imageKey: Key(
                                        'conversation-background-image-${conversation.id}',
                                      ),
                                      uri: profileMediaUri,
                                      load: onLoadMediaThumbnail,
                                      cachedBytes: cachedMediaThumbnail(
                                        profileMediaUri,
                                      ),
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

class _MatrixMediaBackgroundImage extends StatefulWidget {
  const _MatrixMediaBackgroundImage({
    super.key,
    required this.imageKey,
    required this.uri,
    required this.load,
    required this.cachedBytes,
  });

  final Key imageKey;
  final Uri uri;
  final Future<Uint8List> Function(Uri) load;
  final Uint8List? cachedBytes;

  @override
  State<_MatrixMediaBackgroundImage> createState() =>
      _MatrixMediaBackgroundImageState();
}

class _MatrixMediaBackgroundImageState
    extends State<_MatrixMediaBackgroundImage> {
  Uint8List? _bytes;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bytes = widget.cachedBytes;
    _load();
  }

  @override
  void didUpdateWidget(_MatrixMediaBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || oldWidget.load != widget.load) {
      _bytes = widget.cachedBytes ?? _bytes;
      _load();
    }
  }

  void _load() {
    final generation = ++_loadGeneration;
    widget
        .load(widget.uri)
        .then(
          (bytes) {
            if (!mounted || generation != _loadGeneration) return;
            setState(() => _bytes = bytes);
          },
          onError: (Object _) {
            // Keep the previous background during a transient media failure. A
            // later avatar URI update will start another authenticated download.
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return AnimatedOpacity(
      opacity: bytes == null ? 0 : 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: bytes == null
          ? const SizedBox.expand()
          : Image.memory(
              bytes,
              key: widget.imageKey,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              cacheWidth: 16,
              cacheHeight: 16,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}

class _MessageDateSeparator extends StatelessWidget {
  const _MessageDateSeparator({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final local = timestamp.toLocal();
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatMessageDate(timestamp),
              key: Key(
                'message-date-${local.year}-${local.month}-${local.day}',
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: dividerColor)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.showTimestamp,
    required this.showSenderIdentity,
    required this.onLongPress,
    required this.onRequestKey,
    required this.onLoadAttachment,
    required this.onLoadMediaThumbnail,
    required this.onOpenProfilePicture,
    required this.onSaveAttachment,
    required this.onOpenImage,
    required this.onOpenLink,
    required this.onOpenReply,
  });

  final _ChatMessage message;
  final bool showTimestamp;
  final bool showSenderIdentity;
  final VoidCallback onLongPress;
  final VoidCallback onRequestKey;
  final Future<MatrixAttachmentData> Function() onLoadAttachment;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final _OpenProfilePicture onOpenProfilePicture;
  final VoidCallback onSaveAttachment;
  final VoidCallback onOpenImage;
  final ValueChanged<Uri> onOpenLink;
  final VoidCallback? onOpenReply;

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
    if (oldWidget.message.eventId != widget.message.eventId ||
        oldWidget.message.kind != widget.message.kind ||
        oldWidget.message.isUndecryptable != widget.message.isUndecryptable) {
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
    final standaloneMedia = widget.message.kind == MatrixMessageKind.image;
    final useSentBubbleColors = widget.message.sentByMe && !standaloneMedia;
    final deliveryLabel = switch (widget.message.delivery) {
      MatrixMessageDelivery.sending => 'Sending…',
      MatrixMessageDelivery.failed => 'Failed · tap to retry',
      MatrixMessageDelivery.sent => 'Sent',
      MatrixMessageDelivery.synced
          when widget.showTimestamp && widget.message.timestamp != null =>
        _formatMessageTime(widget.message.timestamp!),
      _ => null,
    };
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
              onOpenProfilePicture: widget.onOpenProfilePicture,
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
                key: Key(
                  'message-surface-${widget.message.eventId ?? widget.message.senderId}',
                ),
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: standaloneMedia
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: standaloneMedia
                    ? null
                    : BoxDecoration(
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
                    if (widget.message.replyToEventId != null) ...[
                      _ReplyPreview(
                        eventId: widget.message.replyToEventId!,
                        senderName:
                            widget.message.replyToSenderName ?? 'Message',
                        body:
                            widget.message.replyToBody ??
                            'Original message unavailable',
                        sentByMe: useSentBubbleColors,
                        onTap: widget.onOpenReply,
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (widget.message.kind == MatrixMessageKind.image)
                      _ImageAttachment(
                        data: _image!,
                        name:
                            widget.message.attachmentName ??
                            widget.message.body,
                        foreground: Theme.of(context).colorScheme.onSurface,
                        onRetry: () => setState(() {
                          _image = widget.onLoadAttachment();
                        }),
                        onOpen: widget.onOpenImage,
                        width: widget.message.attachmentWidth,
                        height: widget.message.attachmentHeight,
                      )
                    else if (widget.message.kind != MatrixMessageKind.text)
                      _FileAttachment(
                        message: widget.message,
                        foreground: widget.message.sentByMe
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.onSurface,
                      )
                    else
                      _LinkifiedMessageText(
                        key: Key(
                          'message-text-${widget.message.eventId ?? widget.message.senderId}',
                        ),
                        text: widget.message.body,
                        sentByMe: widget.message.sentByMe,
                        italic: widget.message.isSystem,
                        onOpenLink: widget.onOpenLink,
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
                            foregroundColor: useSentBubbleColors
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
                            color: useSentBubbleColors
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.72)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                    if (widget.message.reactionByMe != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        key: Key(
                          'my-reaction-${widget.message.eventId ?? widget.message.senderId}',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: useSentBubbleColors
                              ? Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.16)
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.message.reactionByMe!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                    if (deliveryLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        deliveryLabel,
                        key: Key(
                          'message-time-${widget.message.eventId ?? widget.message.senderId}',
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color: useSentBubbleColors
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

class _LinkifiedMessageText extends StatefulWidget {
  const _LinkifiedMessageText({
    super.key,
    required this.text,
    required this.sentByMe,
    required this.italic,
    required this.onOpenLink,
  });

  final String text;
  final bool sentByMe;
  final bool italic;
  final ValueChanged<Uri> onOpenLink;

  @override
  State<_LinkifiedMessageText> createState() => _LinkifiedMessageTextState();
}

class _LinkifiedMessageTextState extends State<_LinkifiedMessageText> {
  static final RegExp _linkPattern = RegExp(
    r'(?:(?:https?://)|(?:www\.))[^\s<]+',
    caseSensitive: false,
  );
  final List<TapGestureRecognizer> _recognizers = [];
  late List<_LinkTextPart> _parts;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant _LinkifiedMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.onOpenLink != widget.onOpenLink) {
      _disposeRecognizers();
      _parse();
    }
  }

  void _parse() {
    final parts = <_LinkTextPart>[];
    var cursor = 0;
    for (final match in _linkPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        parts.add(_LinkTextPart(widget.text.substring(cursor, match.start)));
      }
      final matchedText = match.group(0)!;
      var linkLength = matchedText.length;
      while (linkLength > 0 &&
          '.,!?;:)]}'.contains(matchedText[linkLength - 1])) {
        linkLength -= 1;
      }
      final linkText = matchedText.substring(0, linkLength);
      final trailing = matchedText.substring(linkLength);
      final normalized = linkText.toLowerCase().startsWith('www.')
          ? 'https://$linkText'
          : linkText;
      final uri = Uri.tryParse(normalized);
      if (uri != null &&
          uri.host.isNotEmpty &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onOpenLink(uri);
        _recognizers.add(recognizer);
        parts.add(_LinkTextPart(linkText, uri: uri, recognizer: recognizer));
      } else {
        parts.add(_LinkTextPart(linkText));
      }
      if (trailing.isNotEmpty) parts.add(_LinkTextPart(trailing));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      parts.add(_LinkTextPart(widget.text.substring(cursor)));
    }
    _parts = parts;
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.sentByMe
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          height: 1.3,
          fontStyle: widget.italic ? FontStyle.italic : null,
          color: foreground,
        ),
        children: [
          for (final part in _parts)
            TextSpan(
              text: part.text,
              recognizer: part.recognizer,
              style: part.uri == null
                  ? null
                  : TextStyle(
                      color: widget.sentByMe
                          ? foreground
                          : Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: widget.sentByMe
                          ? foreground
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
            ),
        ],
      ),
    );
  }
}

final class _LinkTextPart {
  const _LinkTextPart(this.text, {this.uri, this.recognizer});

  final String text;
  final Uri? uri;
  final TapGestureRecognizer? recognizer;
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.eventId,
    required this.senderName,
    required this.body,
    required this.sentByMe,
    required this.onTap,
  });

  final String eventId;
  final String senderName;
  final String body;
  final bool sentByMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = sentByMe
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: onTap != null,
      label: 'Reply to $senderName: $body',
      child: InkWell(
        key: Key('reply-preview-$eventId'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: .1),
            border: Border(
              left: BorderSide(
                color: sentByMe
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withValues(alpha: .78),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageSenderAvatar extends StatefulWidget {
  const _MessageSenderAvatar({
    required this.message,
    required this.onLoadMediaThumbnail,
    required this.onOpenProfilePicture,
  });

  final _ChatMessage message;
  final Future<Uint8List> Function(Uri) onLoadMediaThumbnail;
  final _OpenProfilePicture onOpenProfilePicture;

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
      child: Tooltip(
        message: widget.message.senderAvatarUrl == null
            ? widget.message.senderName ?? widget.message.senderId
            : 'Open ${widget.message.senderName ?? widget.message.senderId} profile picture',
        child: InkWell(
          onTap: widget.message.senderAvatarUrl == null
              ? null
              : () => widget.onOpenProfilePicture(
                  name: widget.message.senderName ?? widget.message.senderId,
                  mediaUri: widget.message.senderAvatarUrl,
                ),
          customBorder: const CircleBorder(),
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
        ),
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
    required this.onOpen,
    required this.width,
    required this.height,
  });

  final Future<MatrixAttachmentData> data;
  final String name;
  final Color foreground;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatrixAttachmentData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final rawAspectRatio =
              width != null && height != null && width! > 0 && height! > 0
              ? width! / height!
              : 4 / 3;
          final aspectRatio = rawAspectRatio.clamp(.2, 5.0);
          var previewWidth = 272.0;
          var previewHeight = previewWidth / aspectRatio;
          if (previewHeight > 300) {
            previewHeight = 300;
            previewWidth = previewHeight * aspectRatio;
          } else if (previewHeight < 96) {
            previewHeight = 96;
          }
          return Semantics(
            button: true,
            label: 'Open $name',
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  key: Key('message-image-frame-$name'),
                  width: previewWidth,
                  height: previewHeight,
                  child: Image.memory(
                    snapshot.data!.bytes,
                    key: Key('message-image-$name'),
                    fit: BoxFit.contain,
                    width: previewWidth,
                    height: previewHeight,
                    errorBuilder: (_, _, _) => _AttachmentError(
                      foreground: foreground,
                      onRetry: onRetry,
                    ),
                  ),
                ),
              ),
            ),
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
    required this.onComposerAction,
    required this.pinnedActions,
    required this.onTogglePinned,
    required this.onKeyboardContent,
    required this.onChanged,
    required this.replyLabel,
    required this.attachmentBusy,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final String conversationId;
  final VoidCallback onSend;
  final ValueChanged<ComposerAction> onComposerAction;
  final List<ComposerAction> pinnedActions;
  final ValueChanged<ComposerAction> onTogglePinned;
  final ValueChanged<KeyboardInsertedContent> onKeyboardContent;
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
            if (pinnedActions.isNotEmpty)
              SizedBox(
                key: const Key('pinned-composer-actions'),
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: pinnedActions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final action = pinnedActions[index];
                    return Tooltip(
                      message:
                          '${_composerActionLabel(action)} · Hold to unpin',
                      child: GestureDetector(
                        onLongPress: () => onTogglePinned(action),
                        child: OutlinedButton.icon(
                          key: Key('pinned-composer-action-${action.name}'),
                          onPressed: attachmentBusy
                              ? null
                              : () => onComposerAction(action),
                          icon: Icon(_composerActionIcon(action), size: 17),
                          label: Text(_composerActionShortLabel(action)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Row(
              children: [
                PopupMenuButton<ComposerAction>(
                  key: const Key('composer-action-menu'),
                  tooltip: 'Add',
                  enabled: !attachmentBusy,
                  onSelected: onComposerAction,
                  itemBuilder: (context) => ComposerAction.values
                      .map(
                        (action) => PopupMenuItem<ComposerAction>(
                          key: Key('composer-action-menu-${action.name}'),
                          value: action,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () {
                              Navigator.pop(context);
                              onTogglePinned(action);
                            },
                            child: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Icon(_composerActionIcon(action), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_composerActionLabel(action)),
                                  ),
                                  if (pinnedActions.contains(action))
                                    const Icon(Icons.push_pin, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
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
                    contentInsertionConfiguration:
                        ContentInsertionConfiguration(
                          allowedMimeTypes: const [
                            'image/gif',
                            'image/png',
                            'image/jpeg',
                            'image/webp',
                          ],
                          onContentInserted: onKeyboardContent,
                        ),
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

String _composerActionLabel(ComposerAction action) => switch (action) {
  ComposerAction.attachFile => 'Attach file',
  ComposerAction.gifSearch => 'Search GIFs',
  ComposerAction.stickerSearch => 'Search stickers',
};

String _composerActionShortLabel(ComposerAction action) => switch (action) {
  ComposerAction.attachFile => 'File',
  ComposerAction.gifSearch => 'GIF',
  ComposerAction.stickerSearch => 'Sticker',
};

IconData _composerActionIcon(ComposerAction action) => switch (action) {
  ComposerAction.attachFile => Icons.attach_file,
  ComposerAction.gifSearch => Icons.gif_box_outlined,
  ComposerAction.stickerSearch => Icons.emoji_emotions_outlined,
};

class _MediaSearchSheet extends StatefulWidget {
  const _MediaSearchSheet({required this.kind, required this.mediaSearch});

  final MediaSearchKind kind;
  final MediaSearchPort mediaSearch;

  @override
  State<_MediaSearchSheet> createState() => _MediaSearchSheetState();
}

class _MediaSearchSheetState extends State<_MediaSearchSheet> {
  final TextEditingController _queryController = TextEditingController();
  List<MediaSearchResult> _results = const [];
  String? _error;
  bool _searching = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.mediaSearch.search(
        query: query,
        kind: widget.kind,
        safety: MediaSearchSafety.open,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == MediaSearchKind.gif ? 'GIFs' : 'stickers';
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Search $label',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: Key('media-search-${widget.kind.name}'),
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search the web and GIF providers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        key: const Key('media-search-submit'),
                        tooltip: 'Search',
                        onPressed: _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(label)),
        ],
      ),
    );
  }

  Widget _buildBody(String label) {
    if (!widget.mediaSearch.isConfigured) {
      return const _MediaSearchMessage(
        icon: Icons.settings_outlined,
        title: 'Media search is not configured',
        body:
            'Build Trace with a media-search relay URL, a GIPHY app key, or '
            'both. Users do not need their own provider keys.',
      );
    }
    if (_error case final error?) {
      return _MediaSearchMessage(
        icon: Icons.error_outline,
        title: 'Search failed',
        body: error,
        action: TextButton(onPressed: _search, child: const Text('Try again')),
      );
    }
    if (_results.isEmpty) {
      return _MediaSearchMessage(
        icon: widget.kind == MediaSearchKind.gif
            ? Icons.gif_box_outlined
            : Icons.emoji_emotions_outlined,
        title: _queryController.text.trim().isEmpty
            ? 'Find $label'
            : 'No results',
        body: _queryController.text.trim().isEmpty
            ? 'Results combine open-web search with curated media providers.'
            : 'Try a different search.',
      );
    }
    return GridView.builder(
      key: const Key('media-search-results'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return Semantics(
          button: true,
          label: '${result.title}, from ${result.source}',
          child: InkWell(
            key: Key('media-search-result-${result.id}'),
            onTap: () => Navigator.pop(context, result),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Image.network(
                      result.previewUri.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 36),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          result.source,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaSearchMessage extends StatelessWidget {
  const _MediaSearchMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body, textAlign: TextAlign.center),
              if (action case final action?) ...[
                const SizedBox(height: 8),
                action,
              ],
            ],
          ),
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

class _ReceivedImageDialog extends StatefulWidget {
  const _ReceivedImageDialog({
    required this.name,
    required this.image,
    required this.onDownload,
  });

  final String name;
  final Future<MatrixAttachmentData> image;
  final Future<void> Function(MatrixAttachmentData attachment) onDownload;

  @override
  State<_ReceivedImageDialog> createState() => _ReceivedImageDialogState();
}

class _ReceivedImageDialogState extends State<_ReceivedImageDialog> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await widget.onDownload(await widget.image);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This image could not be downloaded.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: SafeArea(
      child: Column(
        children: [
          Material(
            color: Colors.black,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    key: const Key('download-received-image'),
                    tooltip: 'Download original',
                    color: Colors.white,
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FutureBuilder<MatrixAttachmentData>(
                future: widget.image,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'This image could not be loaded.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator(color: Colors.white);
                  }
                  return InteractiveViewer(
                    minScale: .5,
                    maxScale: 8,
                    child: Image.memory(
                      snapshot.data!.bytes,
                      key: const Key('received-image-preview'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Text(
                        'This image format cannot be displayed.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfilePictureDialog extends StatefulWidget {
  const _ProfilePictureDialog({
    required this.name,
    required this.image,
    required this.onDownload,
  });

  final String name;
  final Future<Uint8List> image;
  final Future<void> Function(Uint8List bytes) onDownload;

  @override
  State<_ProfilePictureDialog> createState() => _ProfilePictureDialogState();
}

class _ProfilePictureDialogState extends State<_ProfilePictureDialog> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await widget.onDownload(await widget.image);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
      child: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * .86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.name} profile picture',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('download-profile-picture'),
                    tooltip: 'Download original',
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: FutureBuilder<Uint8List>(
                    future: widget.image,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'This profile picture could not be loaded.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return InteractiveViewer(
                        minScale: .5,
                        maxScale: 6,
                        child: Image.memory(
                          snapshot.data!,
                          key: const Key('profile-picture-preview'),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const Text(
                            'This image format cannot be displayed.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
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
    this.mediaUri,
    this.onLoadMediaThumbnail,
    this.diameter = 46,
    this.backgroundColor,
  });

  final String initials;
  final String? imageAsset;
  final Uri? imageUrl;
  final Uri? mediaUri;
  final Future<Uint8List> Function(Uri)? onLoadMediaThumbnail;
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

    if (mediaUri case final uri?) {
      final loader = onLoadMediaThumbnail;
      if (loader != null) {
        return _MatrixMediaAvatar(
          uri: uri,
          load: loader,
          initials: initials,
          diameter: diameter,
          backgroundColor: backgroundColor,
        );
      }
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

class _MatrixMediaAvatar extends StatefulWidget {
  const _MatrixMediaAvatar({
    required this.uri,
    required this.load,
    required this.initials,
    required this.diameter,
    required this.backgroundColor,
  });

  final Uri uri;
  final Future<Uint8List> Function(Uri) load;
  final String initials;
  final double diameter;
  final Color? backgroundColor;

  @override
  State<_MatrixMediaAvatar> createState() => _MatrixMediaAvatarState();
}

class _MatrixMediaAvatarState extends State<_MatrixMediaAvatar> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _image = widget.load(widget.uri);
  }

  @override
  void didUpdateWidget(_MatrixMediaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || oldWidget.load != widget.load) {
      _image = widget.load(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return _InitialsFallback(
            initials: widget.initials,
            diameter: widget.diameter,
            backgroundColor: widget.backgroundColor,
          );
        }
        return ClipOval(
          child: Image.memory(
            bytes,
            width: widget.diameter,
            height: widget.diameter,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => _InitialsFallback(
              initials: widget.initials,
              diameter: widget.diameter,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        );
      },
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

bool _isSameLocalDay(DateTime first, DateTime second) {
  final firstLocal = first.toLocal();
  final secondLocal = second.toLocal();
  return firstLocal.year == secondLocal.year &&
      firstLocal.month == secondLocal.month &&
      firstLocal.day == secondLocal.day;
}

bool _isToday(DateTime? timestamp, {DateTime? now}) {
  if (timestamp == null) return false;
  return _isSameLocalDay(timestamp, now ?? DateTime.now());
}

String _formatMessageDate(DateTime timestamp, {DateTime? now}) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = timestamp.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  if (_isSameLocalDay(local, localNow)) return 'Today';
  final yesterday = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
  ).subtract(const Duration(days: 1));
  if (_isSameLocalDay(local, yesterday)) return 'Yesterday';
  final label =
      '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}';
  return local.year == localNow.year ? label : '$label ${local.year}';
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

({String extension, String mimeType}) _profileImageFormat(Uint8List bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  if (startsWith(const [0x89, 0x50, 0x4e, 0x47])) {
    return (extension: 'png', mimeType: 'image/png');
  }
  if (startsWith(const [0xff, 0xd8, 0xff])) {
    return (extension: 'jpg', mimeType: 'image/jpeg');
  }
  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) {
    return (extension: 'gif', mimeType: 'image/gif');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return (extension: 'webp', mimeType: 'image/webp');
  }
  return (extension: 'img', mimeType: 'application/octet-stream');
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
    this.profileUrl,
    this.profileMediaUri,
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
  Uri? profileMediaUri;
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
    this.attachmentWidth,
    this.attachmentHeight,
    this.reactionByMe,
    this.replyToEventId,
    this.replyToSenderName,
    this.replyToBody,
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
    attachmentWidth: message.attachmentWidth,
    attachmentHeight: message.attachmentHeight,
    reactionByMe: message.reactionByMe,
    replyToEventId: message.replyToEventId,
    replyToSenderName: message.replyToSenderName,
    replyToBody: message.replyToBody,
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
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String? reactionByMe;
  final String? replyToEventId;
  final String? replyToSenderName;
  final String? replyToBody;
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

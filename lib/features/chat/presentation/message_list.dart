import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps incoming rows on the other side of a fixed sliver origin, so they
/// cannot move the messages someone is reading. At the live edge, follows them.
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.messageIds,
    required this.itemBuilder,
    required this.onLoadOlder,
    this.typingIndicator,
  });

  final List<Object> messageIds;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onLoadOlder;
  final Widget? typingIndicator;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _controller = ScrollController();
  final _originKey = GlobalKey();
  Object? _origin;
  bool _loadingOlder = false;
  int _scrollRevision = 0;

  @override
  void initState() {
    super.initState();
    _origin = widget.messageIds.firstOrNull;
    _followLatest();
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final atBottom =
        !_controller.hasClients ||
        _controller.position.pixels <= _controller.position.minScrollExtent + 1;
    if (!widget.messageIds.contains(_origin)) {
      _origin = widget.messageIds.firstOrNull;
    }
    if (atBottom) _followLatest();
  }

  void _followLatest() {
    final revision = _scrollRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || revision != _scrollRevision) {
        return;
      }
      final position = _controller.position;
      if (position.pixels != position.minScrollExtent) {
        _controller.jumpTo(position.minScrollExtent);
      }
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    _loadingOlder = true;
    try {
      await widget.onLoadOlder();
    } finally {
      _loadingOlder = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final originIndex = widget.messageIds.indexOf(_origin ?? Object());
    final split = originIndex < 0 ? 0 : originIndex;
    final indices = {
      for (var i = 0; i < widget.messageIds.length; i++)
        ValueKey(widget.messageIds[i]): i,
    };
    Widget row(BuildContext context, int index) => KeyedSubtree(
      key: ValueKey(widget.messageIds[index]),
      child: widget.itemBuilder(context, index),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification is ScrollStartNotification &&
                notification.dragDetails != null ||
            notification is UserScrollNotification) {
          _scrollRevision++;
        }
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 120) {
          unawaited(_loadOlder());
        }
        return false;
      },
      child: CustomScrollView(
        controller: _controller,
        reverse: true,
        center: _originKey,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (widget.typingIndicator case final indicator?)
            SliverToBoxAdapter(child: indicator),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => row(context, split - index - 1),
                childCount: split,
                findChildIndexCallback: (key) {
                  final index = indices[key];
                  return index == null || index >= split
                      ? null
                      : split - index - 1;
                },
              ),
            ),
          ),
          SliverPadding(
            key: _originKey,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => row(context, split + index),
                childCount: widget.messageIds.length - split,
                findChildIndexCallback: (key) {
                  final index = indices[key];
                  return index == null || index < split ? null : index - split;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

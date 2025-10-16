import 'package:flutter/material.dart';
import '../../models/message.dart';

/// Optimized message list item with performance enhancements
/// 
/// Features:
/// - RepaintBoundary to isolate repaints
/// - AutomaticKeepAlive to preserve scroll state
/// - Unique keys for efficient widget tree diffing
/// - Const constructors where possible
class OptimizedMessageListItem extends StatefulWidget {
  final Message message;
  final bool isFromUser;
  final bool showAvatar;
  final bool showTimestamp;
  final DateTime? timestamp;
  final Widget Function(Message, bool, bool) messageBuilder;
  final Widget Function(DateTime)? timestampBuilder;

  const OptimizedMessageListItem({
    Key? key,
    required this.message,
    required this.isFromUser,
    required this.showAvatar,
    required this.showTimestamp,
    this.timestamp,
    required this.messageBuilder,
    this.timestampBuilder,
  }) : super(key: key);

  @override
  State<OptimizedMessageListItem> createState() =>
      _OptimizedMessageListItemState();
}

class _OptimizedMessageListItemState extends State<OptimizedMessageListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when scrolling

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      // Isolate this item's repaints from siblings
      child: Column(
        key: ValueKey(widget.message.id),
        children: [
          if (widget.showTimestamp && widget.timestamp != null)
            widget.timestampBuilder?.call(widget.timestamp!) ??
                const SizedBox.shrink(),
          widget.messageBuilder(
            widget.message,
            widget.isFromUser,
            widget.showAvatar,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Message key generator for efficient widget tree updates
class MessageKeys {
  static final Map<String, GlobalKey> _keyCache = {};

  /// Get or create a unique key for a message
  static GlobalKey forMessage(String messageId) {
    return _keyCache.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'message_$messageId'),
    );
  }

  /// Clear cached keys (call when messages are deleted)
  static void clearCache([String? messageId]) {
    if (messageId != null) {
      _keyCache.remove(messageId);
    } else {
      _keyCache.clear();
    }
  }

  /// Get cache statistics
  static Map<String, int> getStats() {
    return {
      'cachedKeys': _keyCache.length,
    };
  }
}

/// Performance metrics for message list
class MessageListMetrics {
  static final Stopwatch _scrollStopwatch = Stopwatch();
  static int _frameCount = 0;
  static int _rebuildCount = 0;
  static final List<Duration> _frameTimes = [];

  /// Start tracking performance
  static void startTracking() {
    _scrollStopwatch.start();
    _frameCount = 0;
    _rebuildCount = 0;
    _frameTimes.clear();
  }

  /// Record a frame
  static void recordFrame() {
    if (_scrollStopwatch.isRunning) {
      _frameCount++;
      _frameTimes.add(_scrollStopwatch.elapsed);
    }
  }

  /// Record a rebuild
  static void recordRebuild() {
    _rebuildCount++;
  }

  /// Stop tracking and get results
  static Map<String, dynamic> stopTracking() {
    _scrollStopwatch.stop();
    final elapsed = _scrollStopwatch.elapsed;
    final fps = _frameCount > 0
        ? (_frameCount / elapsed.inMilliseconds * 1000).round()
        : 0;

    final result = {
      'duration': elapsed.inMilliseconds,
      'frames': _frameCount,
      'rebuilds': _rebuildCount,
      'fps': fps,
      'avgFrameTime': _frameTimes.isNotEmpty
          ? _frameTimes
                  .map((d) => d.inMicroseconds)
                  .reduce((a, b) => a + b) ~/
              _frameTimes.length
          : 0,
    };

    _scrollStopwatch.reset();
    return result;
  }

  /// Reset all metrics
  static void reset() {
    _scrollStopwatch.reset();
    _frameCount = 0;
    _rebuildCount = 0;
    _frameTimes.clear();
  }
}

/// Optimized ListView builder with performance enhancements
class OptimizedMessageListView extends StatefulWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final Widget Function(Message, bool, bool) messageBuilder;
  final Widget Function(DateTime)? timestampBuilder;
  final bool Function(List<Message>, int, bool) shouldShowAvatar;
  final bool Function(List<Message>, int) shouldShowTimestamp;
  final String currentUserId;

  const OptimizedMessageListView({
    Key? key,
    required this.messages,
    required this.scrollController,
    required this.messageBuilder,
    this.timestampBuilder,
    required this.shouldShowAvatar,
    required this.shouldShowTimestamp,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<OptimizedMessageListView> createState() =>
      _OptimizedMessageListViewState();
}

class _OptimizedMessageListViewState extends State<OptimizedMessageListView> {
  // Cache for computed values
  final Map<int, bool> _avatarCache = {};
  final Map<int, bool> _timestampCache = {};

  @override
  void didUpdateWidget(OptimizedMessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Clear cache if messages changed
    if (oldWidget.messages.length != widget.messages.length) {
      _avatarCache.clear();
      _timestampCache.clear();
    }
  }

  bool _getCachedShowAvatar(int index, bool isFromUser) {
    return _avatarCache.putIfAbsent(
      index,
      () => widget.shouldShowAvatar(widget.messages, index, isFromUser),
    );
  }

  bool _getCachedShowTimestamp(int index) {
    return _timestampCache.putIfAbsent(
      index,
      () => widget.shouldShowTimestamp(widget.messages, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use ListView.builder with addAutomaticKeepAlives for better performance
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.messages.length,
      // Performance optimizations
      addAutomaticKeepAlives: true, // Keep offscreen items alive
      addRepaintBoundaries: true, // Add repaint boundaries automatically
      cacheExtent: 500, // Cache 500 pixels above/below viewport
      
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isFromUser = message.sender.id == widget.currentUserId;
        final showAvatar = _getCachedShowAvatar(index, isFromUser);
        final showTimestamp = _getCachedShowTimestamp(index);
        final timestamp = showTimestamp ? message.createdAt : null;

        return OptimizedMessageListItem(
          key: MessageKeys.forMessage(message.id),
          message: message,
          isFromUser: isFromUser,
          showAvatar: showAvatar,
          showTimestamp: showTimestamp,
          timestamp: timestamp,
          messageBuilder: widget.messageBuilder,
          timestampBuilder: widget.timestampBuilder,
        );
      },
    );
  }

  @override
  void dispose() {
    _avatarCache.clear();
    _timestampCache.clear();
    super.dispose();
  }
}

/// Builder for creating optimized custom scroll views
class OptimizedSliverMessageList extends StatelessWidget {
  final List<Message> messages;
  final Widget Function(Message, bool, bool) messageBuilder;
  final Widget Function(DateTime)? timestampBuilder;
  final bool Function(List<Message>, int, bool) shouldShowAvatar;
  final bool Function(List<Message>, int) shouldShowTimestamp;
  final String currentUserId;

  const OptimizedSliverMessageList({
    Key? key,
    required this.messages,
    required this.messageBuilder,
    this.timestampBuilder,
    required this.shouldShowAvatar,
    required this.shouldShowTimestamp,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final message = messages[index];
          final isFromUser = message.sender.id == currentUserId;
          final showAvatar = shouldShowAvatar(messages, index, isFromUser);
          final showTimestamp = shouldShowTimestamp(messages, index);
          final timestamp = showTimestamp ? message.createdAt : null;

          return RepaintBoundary(
            child: Column(
              key: ValueKey(message.id),
              children: [
                if (showTimestamp && timestamp != null)
                  timestampBuilder?.call(timestamp) ??
                      const SizedBox.shrink(),
                messageBuilder(message, isFromUser, showAvatar),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
        childCount: messages.length,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: false, // We're manually adding them
      ),
    );
  }
}

/// Viewport-based rendering helper
class MessageViewportTracker {
  final ScrollController scrollController;
  final double itemHeight;
  final VoidCallback? onViewportChanged;

  MessageViewportTracker({
    required this.scrollController,
    this.itemHeight = 100.0, // Average message height
    this.onViewportChanged,
  }) {
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    onViewportChanged?.call();
  }

  /// Get visible item range based on scroll position
  Map<String, int> getVisibleRange(int totalItems) {
    final scrollOffset = scrollController.offset;
    final viewportHeight = scrollController.position.viewportDimension;

    final firstVisibleIndex =
        (scrollOffset / itemHeight).floor().clamp(0, totalItems - 1);
    final lastVisibleIndex = ((scrollOffset + viewportHeight) / itemHeight)
        .ceil()
        .clamp(0, totalItems - 1);

    return {
      'first': firstVisibleIndex,
      'last': lastVisibleIndex,
      'count': (lastVisibleIndex - firstVisibleIndex + 1).clamp(0, totalItems),
    };
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
  }
}

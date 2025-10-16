import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reaction_picker.dart';
import 'reactions_display.dart';
import '../../services/reactions_api_service.dart';

/// Example widget showing how to integrate reactions with a message bubble
///
/// Usage in your message bubble widget:
/// ```dart
/// MessageReactionHandler(
///   messageId: message.id,
///   userId: currentUserId,
///   businessId: businessId,
///   userName: currentUserName,
///   child: YourMessageBubbleWidget(...),
/// )
/// ```
class MessageReactionHandler extends ConsumerStatefulWidget {
  final String messageId;
  final String userId;
  final String businessId;
  final String? userName;
  final Widget child;

  const MessageReactionHandler({
    super.key,
    required this.messageId,
    required this.userId,
    required this.businessId,
    this.userName,
    required this.child,
  });

  @override
  ConsumerState<MessageReactionHandler> createState() =>
      _MessageReactionHandlerState();
}

class _MessageReactionHandlerState
    extends ConsumerState<MessageReactionHandler> {
  bool _showReactionPicker = false;
  OverlayEntry? _overlayEntry;
  final ReactionsApiService _reactionsService = ReactionsApiService();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showReactionPicker = false;
  }

  void _showReactionPickerOverlay(BuildContext context) {
    if (_showReactionPicker) {
      _removeOverlay();
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Reaction picker positioned above message
          Positioned(
            left: offset.dx,
            top: offset.dy - 60, // Position above the message
            child: Material(
              color: Colors.transparent,
              child: ReactionPicker(
                onReactionSelected: (emoji) {
                  _addReaction(emoji);
                  _removeOverlay();
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showReactionPicker = true);
  }

  Future<void> _addReaction(String emoji) async {
    try {
      await _reactionsService.addReaction(
        messageId: widget.messageId,
        userId: widget.userId,
        businessId: widget.businessId,
        emoji: emoji,
        userName: widget.userName,
        platform: 'app',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reaction added: $emoji'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeReaction(String reactionId) async {
    try {
      await _reactionsService.removeReaction(
        messageId: widget.messageId,
        reactionId: reactionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reaction removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove reaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message bubble with long-press to show reactions
        GestureDetector(
          onLongPress: () => _showReactionPickerOverlay(context),
          child: widget.child,
        ),
        // Display existing reactions
        ReactionsDisplay(
          messageId: widget.messageId,
          currentUserId: widget.userId,
          onReactionTap: (emoji) {
            // Tapping a reaction adds/removes it
          },
          onAddReaction: _addReaction,
          onRemoveReaction: _removeReaction,
        ),
      ],
    );
  }
}

/// Simple example of how to use reactions in a message list
///
/// ```dart
/// ListView.builder(
///   itemCount: messages.length,
///   itemBuilder: (context, index) {
///     final message = messages[index];
///     return MessageReactionHandler(
///       messageId: message.id,
///       userId: currentUserId,
///       businessId: businessId,
///       userName: currentUserName,
///       child: MessageBubble(message: message),
///     );
///   },
/// )
/// ```
class ReactionUsageExample extends StatelessWidget {
  const ReactionUsageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reactions Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Long-press on a message to add reactions'),
            const SizedBox(height: 20),
            MessageReactionHandler(
              messageId: 'example_message_123',
              userId: 'current_user_123',
              businessId: 'business_123',
              userName: 'John Doe',
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Long-press me to add reactions!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

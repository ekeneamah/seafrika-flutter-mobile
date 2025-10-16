import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a single reaction
class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String businessId;
  final String? userName;
  final String emoji;
  final String platform;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.businessId,
    this.userName,
    required this.emoji,
    required this.platform,
    required this.createdAt,
  });

  factory MessageReaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageReaction(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      businessId: data['businessId'] ?? '',
      userName: data['userName'],
      emoji: data['emoji'] ?? '',
      platform: data['platform'] ?? 'app',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Widget to display reactions below a message
class ReactionsDisplay extends StatefulWidget {
  final String messageId;
  final String currentUserId;
  final Function(String emoji) onReactionTap;
  final Function(String emoji) onAddReaction;
  final Function(String reactionId) onRemoveReaction;

  const ReactionsDisplay({
    super.key,
    required this.messageId,
    required this.currentUserId,
    required this.onReactionTap,
    required this.onAddReaction,
    required this.onRemoveReaction,
  });

  @override
  State<ReactionsDisplay> createState() => _ReactionsDisplayState();
}

class _ReactionsDisplayState extends State<ReactionsDisplay> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.messageId)
          .collection('reactions')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final reactions = snapshot.data!.docs
            .map((doc) => MessageReaction.fromFirestore(doc))
            .toList();

        // Group reactions by emoji
        final groupedReactions = <String, List<MessageReaction>>{};
        for (final reaction in reactions) {
          groupedReactions.putIfAbsent(reaction.emoji, () => []).add(reaction);
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: groupedReactions.entries.map((entry) {
              final emoji = entry.key;
              final reactionList = entry.value;
              final hasUserReacted = reactionList.any(
                (r) => r.userId == widget.currentUserId,
              );
              final userReaction = reactionList.firstWhere(
                (r) => r.userId == widget.currentUserId,
                orElse: () => reactionList.first,
              );

              return _ReactionBubble(
                emoji: emoji,
                count: reactionList.length,
                hasUserReacted: hasUserReacted,
                onTap: () {
                  if (hasUserReacted) {
                    widget.onRemoveReaction(userReaction.id);
                  } else {
                    widget.onAddReaction(emoji);
                  }
                },
                onLongPress: () =>
                    _showReactionDetails(context, emoji, reactionList),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showReactionDetails(
    BuildContext context,
    String emoji,
    List<MessageReaction> reactions,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Text(
                  '${reactions.length} ${reactions.length == 1 ? 'reaction' : 'reactions'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...reactions.map((reaction) {
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    reaction.userName?.substring(0, 1).toUpperCase() ?? 'U',
                  ),
                ),
                title: Text(reaction.userName ?? 'Unknown User'),
                subtitle: Text(_formatTimestamp(reaction.createdAt)),
                trailing: _getPlatformIcon(reaction.platform),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'messenger':
        return const Icon(Icons.messenger, color: Colors.blue, size: 20);
      case 'instagram':
        return const Icon(Icons.camera_alt, color: Colors.pink, size: 20);
      case 'whatsapp':
        return const Icon(Icons.phone, color: Colors.green, size: 20);
      default:
        return const Icon(Icons.phone_android, color: Colors.grey, size: 20);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _ReactionBubble extends StatefulWidget {
  final String emoji;
  final int count;
  final bool hasUserReacted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReactionBubble({
    required this.emoji,
    required this.count,
    required this.hasUserReacted,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ReactionBubble> createState() => _ReactionBubbleState();
}

class _ReactionBubbleState extends State<_ReactionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Animate on first appearance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.hasUserReacted
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.grey.shade200,
            border: Border.all(
              color: widget.hasUserReacted
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
              width: widget.hasUserReacted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.emoji,
                style: const TextStyle(fontSize: 16),
              ),
              if (widget.count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.hasUserReacted
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

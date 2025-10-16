import 'package:flutter/material.dart';

/// Emoji reaction picker widget
class ReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;
  final List<String> quickReactions;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.quickReactions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...quickReactions.map((emoji) => _ReactionButton(
                emoji: emoji,
                onTap: () => onReactionSelected(emoji),
              )),
          const SizedBox(width: 4),
          _MoreReactionsButton(
            onEmojiSelected: onReactionSelected,
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}

class _MoreReactionsButton extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const _MoreReactionsButton({
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      iconSize: 28,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      onPressed: () => _showFullEmojiPicker(context),
    );
  }

  void _showFullEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FullEmojiPicker(
        onEmojiSelected: (emoji) {
          onEmojiSelected(emoji);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _FullEmojiPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const _FullEmojiPicker({
    required this.onEmojiSelected,
  });

  // Categorized emoji list
  static const Map<String, List<String>> emojiCategories = {
    'Smileys': [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😙',
      '🥲',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
    ],
    'Gestures': [
      '🤚',
      '✋',
      '🖐️',
      '👋',
      '🤙',
      '💪',
      '🦾',
      '🖕',
      '✍️',
      '🙏',
      '🦶',
      '🦵',
      '👂',
      '🦻',
      '👃',
      '🧠',
      '🦷',
      '🦴',
      '👀',
      '👁️',
      '👅',
      '👄',
      '💋',
      '🩸',
    ],
    'Hearts': [
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '☮️',
      '✝️',
      '☪️',
      '🕉️',
      '☸️',
    ],
    'Objects': [
      '💬',
      '👁️‍🗨️',
      '💭',
      '💤',
      '💢',
      '💥',
      '💫',
      '💦',
      '💨',
      '🕳️',
      '💣',
      '💬',
      '👁️‍🗨️',
      '🗨️',
      '🗯️',
      '💭',
      '💤',
      '👋',
      '🤚',
      '🖐️',
      '✋',
      '🖖',
      '👌',
      '🤌',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Reaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: emojiCategories.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((emoji) {
                        return GestureDetector(
                          onTap: () => onEmojiSelected(emoji),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

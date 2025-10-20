import 'package:flutter/material.dart';
import '../../models/message.dart';

/// Widget to show thread indicator in message bubble
class ThreadIndicator extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;

  const ThreadIndicator({
    Key? key,
    required this.message,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show indicator if message is a reply (has replyToId)
    final isReply = message.metadata.replyToId != null;
    
    // Show indicator if message has replies
    final hasReplies = (message.metadata.replyCount ?? 0) > 0;

    if (!isReply && !hasReplies) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReply ? Icons.subdirectory_arrow_right : Icons.forum,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            if (isReply)
              Text(
                'Reply',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                '${message.metadata.replyCount} ${message.metadata.replyCount == 1 ? 'reply' : 'replies'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

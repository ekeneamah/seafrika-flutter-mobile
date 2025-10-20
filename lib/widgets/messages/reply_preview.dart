import 'package:flutter/material.dart';
import '../../models/message.dart';

/// Widget to show parent message preview when replying
class ReplyPreview extends StatelessWidget {
  final Message parentMessage;
  final VoidCallback onCancel;

  const ReplyPreview({
    Key? key,
    required this.parentMessage,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_getSenderName(parentMessage)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getMessagePreview(parentMessage),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  String _getSenderName(Message message) {
    // You may want to fetch actual user names from a user service
    return message.metadata.source == 'business' ? 'You' : 'Customer';
  }

  String _getMessagePreview(Message message) {
    if (message.content.text != null && message.content.text!.isNotEmpty) {
      return message.content.text!;
    }
    
    if (message.content.attachments.isNotEmpty) {
      final attachment = message.content.attachments.first;
      return '[${attachment.type}]';
    }
    
    return 'Message';
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/message.dart';
import '../../config/theme.dart';
import '../../services/drafts_api_service.dart';

class ConversationList extends StatelessWidget {
  final List<Conversation> conversations;
  final Function(Conversation) onConversationTap;

  const ConversationList({
    Key? key,
    required this.conversations,
    required this.onConversationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start engaging with your customers\nto see conversations here',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return ConversationTile(
          conversation: conversation,
          onTap: () => onConversationTap(conversation),
        );
      },
    );
  }
}

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    Key? key,
    required this.conversation,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Platform Icon and Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getPlatformColor(conversation.platform),
                    child: Text(
                      conversation.platform.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : conversation.unreadCount.toString(),
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Conversation Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getParticipantName(conversation),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status indicators
                        Row(
                          children: [
                            if (conversation.isPinned)
                              Icon(
                                Icons.push_pin,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            if (conversation.isArchived)
                              Icon(
                                Icons.archive,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(conversation.lastMessageAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Platform and Type
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getPlatformColor(conversation.platform)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            conversation.platform.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getPlatformColor(conversation.platform),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            conversation.type.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Last Message Preview (with draft support - Task #17)
                    FutureBuilder<DraftResult?>(
                      future: DraftsApiService().getDraft(conversation.id),
                      builder: (context, snapshot) {
                        // Show draft if exists
                        if (snapshot.hasData && snapshot.data != null) {
                          final draft = snapshot.data!;
                          return Row(
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Draft: ${draft.text}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: theme.colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }

                        // Otherwise show last message preview
                        if (conversation.lastMessagePreview != null) {
                          return Text(
                            conversation.lastMessagePreview!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: conversation.unreadCount > 0
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),

                    // Tags
                    if (conversation.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: conversation.tags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // Action Button
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          conversation.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(conversation.isPinned ? 'Unpin' : 'Pin'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          conversation.isArchived
                              ? Icons.unarchive
                              : Icons.archive,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(conversation.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  if (conversation.unreadCount > 0)
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read, size: 20),
                          SizedBox(width: 8),
                          Text('Mark as Read'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getParticipantName(Conversation conversation) {
    if (conversation.participants.isNotEmpty) {
      final participant = conversation.participants.first;
      return participant.name ?? participant.id;
    }
    return 'Unknown User';
  }

  Color _getPlatformColor(MessagePlatform platform) {
    switch (platform) {
      case MessagePlatform.facebook:
        return const Color(0xFF1877F2);
      case MessagePlatform.instagram:
        return const Color(0xFFE4405F);
      case MessagePlatform.messenger:
        return const Color(0xFF00B2FF);
      case MessagePlatform.whatsapp:
        return const Color(0xFF25D366);
      case MessagePlatform.tiktok:
        return const Color(0xFF000000);
      case MessagePlatform.youtube:
        return const Color(0xFFFF0000);
      case MessagePlatform.email:
        return const Color(0xFF34A853);
      case MessagePlatform.sms:
        return const Color(0xFF2196F3);
      case MessagePlatform.website:
        return const Color(0xFF9C27B0);
      case MessagePlatform.phone:
        return const Color(0xFF4CAF50);
    }
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'pin':
        // TODO: Implement pin/unpin functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              conversation.isPinned
                  ? 'Conversation unpinned'
                  : 'Conversation pinned',
            ),
          ),
        );
        break;
      case 'archive':
        // TODO: Implement archive/unarchive functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              conversation.isArchived
                  ? 'Conversation unarchived'
                  : 'Conversation archived',
            ),
          ),
        );
        break;
      case 'mark_read':
        // TODO: Implement mark as read functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation marked as read'),
          ),
        );
        break;
      case 'delete':
        // TODO: Implement delete functionality with confirmation
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation deleted'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

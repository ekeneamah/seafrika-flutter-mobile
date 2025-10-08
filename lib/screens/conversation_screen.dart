import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../providers/messages_provider.dart';
import '../widgets/messages/message_bubble.dart';
import '../widgets/messages/message_input.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ConversationScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsyncValue = ref.watch(
      conversationMessagesProvider(widget.conversation.id),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getParticipantName(widget.conversation),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Text(
                  widget.conversation.platform.icon,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.conversation.platform.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.conversation.type.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.conversation.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: () => _markAsRead(),
              tooltip: 'Mark as read',
            ),
          IconButton(
            icon: Icon(
              widget.conversation.isPinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
            ),
            onPressed: () => _togglePin(),
            tooltip: widget.conversation.isPinned ? 'Unpin' : 'Pin',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      widget.conversation.isArchived
                          ? Icons.unarchive
                          : Icons.archive,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.conversation.isArchived
                        ? 'Unarchive'
                        : 'Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export conversation'),
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
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Conversation Info Banner
          if (widget.conversation.tags.isNotEmpty ||
              widget.conversation.metadata.sourcePostId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.conversation.metadata.sourcePostId != null)
                    Text(
                      'From post: ${widget.conversation.metadata.sourcePostId}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (widget.conversation.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.conversation.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: messagesAsyncValue.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation',
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isNextMessageFromSameUser = index > 0 &&
                        messages[index - 1].sender.id == message.sender.id;
                    final isPrevMessageFromSameUser =
                        index < messages.length - 1 &&
                            messages[index + 1].sender.id == message.sender.id;

                    return MessageBubble(
                      message: message,
                      showAvatar: !isNextMessageFromSameUser,
                      showTimestamp: !isPrevMessageFromSameUser,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading messages',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(
                        conversationMessagesProvider(widget.conversation.id),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Message Input
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            conversation: widget.conversation,
          ),
        ],
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

  void _markAsRead() async {
    try {
      final messagesService = ref.read(messagesServiceProvider);
      final businessId = ref.read(currentBusinessProvider);

      if (businessId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business selected')),
        );
        return;
      }

      await messagesService.markConversationAsRead(
          businessId, widget.conversation.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking as read: $e')),
      );
    }
  }

  void _togglePin() async {
    try {
      final messagesService = ref.read(messagesServiceProvider);
      final businessId = ref.read(currentBusinessProvider);

      if (businessId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business selected')),
        );
        return;
      }

      await messagesService.toggleConversationPin(
        businessId,
        widget.conversation.id,
        !widget.conversation.isPinned,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.conversation.isPinned ? 'Unpinned' : 'Pinned',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating pin status: $e')),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'archive':
        _toggleArchive();
        break;
      case 'export':
        _exportConversation();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _toggleArchive() async {
    try {
      final messagesService = ref.read(messagesServiceProvider);
      final businessId = ref.read(currentBusinessProvider);

      if (businessId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business selected')),
        );
        return;
      }

      await messagesService.toggleConversationArchive(
        businessId,
        widget.conversation.id,
        !widget.conversation.isArchived,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.conversation.isArchived ? 'Unarchived' : 'Archived',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating archive status: $e')),
      );
    }
  }

  void _exportConversation() {
    // TODO: Implement conversation export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon'),
      ),
    );
  }

  void _showDeleteConfirmation() {
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
              Navigator.pop(context); // Go back to messages list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation deleted')),
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

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final messagesService = ref.read(messagesServiceProvider);
      final businessId = ref.read(currentBusinessProvider);

      if (businessId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business selected')),
        );
        return;
      }

      final message = Message(
        id: '', // Will be generated by Firestore
        businessId: businessId,
        integrationId: widget.conversation.integrationId,
        conversationId: widget.conversation.id,
        platform: widget.conversation.platform,
        type: MessageType.text,
        content: MessageContent(text: text),
        sender: MessageSender(
          id: 'business-user', // TODO: Get current user ID
          name: 'Business',
          isCustomer: false,
        ),
        recipient: MessageRecipient(
          id: widget.conversation.participants.first.id,
          name: widget.conversation.participants.first.name,
        ),
        metadata: MessageMetadata(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          source: 'app',
          isRead: true,
          isReplied: false,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await messagesService.sendMessage(businessId, message);
      _messageController.clear();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }
}

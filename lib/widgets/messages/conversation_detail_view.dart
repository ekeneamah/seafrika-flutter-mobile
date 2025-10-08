import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

class ConversationDetailView extends ConsumerStatefulWidget {
  final Conversation conversation;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const ConversationDetailView({
    Key? key,
    required this.conversation,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  ConsumerState<ConversationDetailView> createState() =>
      _ConversationDetailViewState();
}

class _ConversationDetailViewState
    extends ConsumerState<ConversationDetailView> {
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
    final messagesAsync = ref.watch(messagesProvider(widget.conversation.id));

    return Column(
      children: [
        // Header
        _buildHeader(),

        // Messages
        Expanded(
          child: messagesAsync.when(
            data: (messages) => _buildMessagesList(messages),
            loading: () => _buildLoadingState(),
            error: (error, stackTrace) => _buildErrorState(error),
          ),
        ),

        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildHeader() {
    final participant = widget.conversation.participants.isNotEmpty
        ? widget.conversation.participants.first
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button (mobile)
          if (widget.showBackButton) ...[
            IconButton(
              onPressed: widget.onBackPressed,
              icon: const Icon(Icons.arrow_back),
              iconSize: 20,
              color: AppTheme.textPrimary,
            ),
            const SizedBox(width: 8),
          ],

          // Participant avatar
          _buildParticipantAvatar(participant),

          const SizedBox(width: 12),

          // Participant info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant?.name ?? 'Unknown User',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformBadge(
                        widget.conversation.platform.displayName),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(participant),
                      size: 12,
                      color: _getStatusColor(participant),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(participant),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _togglePin(),
                icon: Icon(
                  widget.conversation.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: widget.conversation.isPinned
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _showConversationOptions(),
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar(ConversationParticipant? participant) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getPlatformColor(widget.conversation.platform.value)
            .withOpacity(0.1),
        border: Border.all(
          color: _getPlatformColor(widget.conversation.platform.value)
              .withOpacity(0.2),
          width: 1,
        ),
      ),
      child: _buildInitialsAvatar(participant?.name ?? 'U'),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return Center(
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getPlatformColor(platform).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getPlatformColor(platform).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/${platform.toLowerCase()}.png',
            width: 12,
            height: 12,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                platform.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: _getPlatformColor(platform),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            platform,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _getPlatformColor(platform),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<Message> messages) {
    if (messages.isEmpty) {
      return _buildEmptyMessagesState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isFromUser =
            message.sender.id == 'current_user'; // TODO: Get actual user ID
        final showAvatar = _shouldShowAvatar(messages, index, isFromUser);
        final showTimestamp = _shouldShowTimestamp(messages, index);

        return Column(
          children: [
            if (showTimestamp) _buildTimestampDivider(message.createdAt),
            _buildMessageBubble(message, isFromUser, showAvatar),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(
      Message message, bool isFromUser, bool showAvatar) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isFromUser && showAvatar) ...[
          _buildMessageAvatar(message.sender.id),
          const SizedBox(width: 8),
        ] else if (!isFromUser) ...[
          const SizedBox(width: 40),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isFromUser ? AppTheme.primary : Colors.grey[100],
              borderRadius: BorderRadius.circular(12).copyWith(
                bottomLeft:
                    !isFromUser && showAvatar ? const Radius.circular(4) : null,
                bottomRight:
                    isFromUser && showAvatar ? const Radius.circular(4) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.text != null) ...[
                  Text(
                    message.content.text!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isFromUser ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],

                // TODO: Handle different message types (image, video, etc.)
                if (message.type != MessageType.text) ...[
                  const SizedBox(height: 4),
                  _buildAttachmentPreview(message),
                ],

                const SizedBox(height: 4),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isFromUser
                            ? Colors.white.withOpacity(0.7)
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (isFromUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.metadata.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.metadata.isRead
                            ? Colors.blue
                            : Colors.white.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isFromUser && showAvatar) ...[
          const SizedBox(width: 8),
          _buildMessageAvatar('current_user'), // TODO: Get actual user ID
        ] else if (isFromUser) ...[
          const SizedBox(width: 40),
        ],
      ],
    );
  }

  Widget _buildMessageAvatar(String senderId) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          'U', // TODO: Get user initials
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatMessageDate(timestamp),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(Message message) {
    // TODO: Implement attachment previews based on message type
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getMessageTypeIcon(message.type),
            size: 16,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(width: 6),
          Text(
            _getMessageTypeLabel(message.type),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showAttachmentOptions(),
            icon: const Icon(Icons.add),
            color: AppTheme.textSecondary,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.primary.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.primary.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;

              return CircleAvatar(
                radius: 20,
                backgroundColor: hasText
                    ? AppTheme.primary
                    : AppTheme.textSecondary.withOpacity(0.3),
                child: IconButton(
                  onPressed: hasText ? _sendMessage : null,
                  icon: Icon(
                    hasText ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessagesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load messages',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _shouldShowAvatar(List<Message> messages, int index, bool isFromUser) {
    if (index == messages.length - 1) return true;

    final currentMessage = messages[index];
    final nextMessage = messages[index + 1];

    return currentMessage.sender.id != nextMessage.sender.id ||
        nextMessage.createdAt.difference(currentMessage.createdAt).inMinutes >
            5;
  }

  bool _shouldShowTimestamp(List<Message> messages, int index) {
    if (index == 0) return true;

    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];

    return currentMessage.createdAt
            .difference(previousMessage.createdAt)
            .inHours >
        1;
  }

  IconData _getStatusIcon(ConversationParticipant? participant) {
    // TODO: Implement real status logic
    return Icons.circle;
  }

  Color _getStatusColor(ConversationParticipant? participant) {
    // TODO: Implement real status logic
    return Colors.green;
  }

  String _getStatusText(ConversationParticipant? participant) {
    // TODO: Implement real status logic
    return 'Online';
  }

  Color _getPlatformColor(String? platform) {
    if (platform == null) return AppTheme.primary;

    switch (platform.toLowerCase()) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'messenger':
        return const Color(0xFF0084FF);
      default:
        return AppTheme.primary;
    }
  }

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.mic;
      case MessageType.file:
        return Icons.attach_file;
      default:
        return Icons.message;
    }
  }

  String _getMessageTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.file:
        return 'File';
      default:
        return 'Message';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatMessageDate(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return days[timestamp.weekday - 1];
    } else {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
    }
  }

  void _togglePin() {
    // TODO: Implement pin toggle
  }

  void _showConversationOptions() {
    // TODO: Show conversation options bottom sheet
  }

  void _showAttachmentOptions() {
    // TODO: Show attachment options bottom sheet
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // TODO: Implement send message
    _messageController.clear();
  }
}

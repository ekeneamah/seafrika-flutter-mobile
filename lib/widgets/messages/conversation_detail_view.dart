import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/typing_indicator_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/typing_indicator_service.dart';
import '../../services/attachment_upload_service.dart';
import 'message_input.dart';
import 'attachment_preview.dart';
import 'typing_indicator.dart';
import 'date_divider.dart';
import 'message_reaction_handler.dart';
import 'optimized_message_list.dart';

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
  final AttachmentUploadService _uploadService = AttachmentUploadService();

  // Attachment state
  final List<File> _attachments = [];
  final List<String> _attachmentTypes = [];
  final Map<int, double> _uploadProgress = {};
  bool _isUploading = false;

  // Typing indicator state
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;

  // Scroll behavior state
  bool _showScrollToBottom = false;
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// Scroll listener to track scroll position and show/hide scroll-to-bottom button
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;

    // Since ListView is reversed, position 0 is at bottom
    // Show button when scrolled up more than 200px from bottom
    final shouldShow = scrollOffset > 200;
    final isAtBottom = scrollOffset < 100;

    if (shouldShow != _showScrollToBottom || isAtBottom != _isAtBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
        _isAtBottom = isAtBottom;
      });
    }
  }

  /// Scroll to bottom of the conversation with animation
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      0, // Position 0 is bottom for reversed ListView
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamProvider for real-time message updates
    // Note: For pagination, use: ref.watch(paginatedMessagesProvider(widget.conversation.id))
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversation.id));

    // Auto-scroll to bottom on new messages if user is already at bottom
    ref.listen<AsyncValue<List<Message>>>(
      messagesStreamProvider(widget.conversation.id),
      (previous, next) {
        if (_isAtBottom && next.hasValue) {
          // Wait for frame to render before scrolling
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && _isAtBottom) {
              _scrollToBottom();
            }
          });
        }
      },
    );

    return Stack(
      children: [
        Column(
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

            // Message input with keyboard awareness
            _buildMessageInput(),
          ],
        ),

        // Scroll to bottom button
        Positioned(
          right: 16,
          bottom: 80, // Position above the input field
          child: AnimatedOpacity(
            opacity: _showScrollToBottom ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _showScrollToBottom
                ? FloatingActionButton(
                    mini: true,
                    onPressed: _scrollToBottom,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
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
                // Show typing indicator or status
                _buildStatusOrTyping(participant),
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

    // Use optimized message list with performance enhancements
    return OptimizedMessageListView(
      messages: messages,
      scrollController: _scrollController,
      messageBuilder: _buildMessageBubble,
      timestampBuilder: _buildTimestampDivider,
      shouldShowAvatar: _shouldShowAvatar,
      shouldShowTimestamp: _shouldShowTimestamp,
      currentUserId: 'current_user', // TODO: Get actual user ID
    );
  }

  Widget _buildMessageBubble(
      Message message, bool isFromUser, bool showAvatar) {
    // Get current user info
    final authService = ref.read(authServiceProvider);
    final currentUserId = authService.currentUser?.id ?? 'unknown_user';
    final currentUserName = authService.currentUser?.fullName ?? 'User';
    
    return MessageReactionHandler(
      messageId: message.id,
      userId: currentUserId,
      businessId: widget.conversation.businessId,
      userName: currentUserName,
      child: Row(
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
      ),
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
    return DateDivider(
      dateText: _formatMessageDate(timestamp),
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
    print(
        '🎯 Building message input - bottom inset: ${MediaQuery.of(context).viewInsets.bottom}');

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment previews
          if (_attachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attachments (${_attachments.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AttachmentPreviewList(
                    files: _attachments,
                    attachmentTypes: _attachmentTypes,
                    onRemove: _removeAttachment,
                    onView: _viewAttachment,
                  ),
                ],
              ),
            ),

          // Upload progress
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Uploading attachments...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Message input row
          Container(
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
                  onPressed:
                      _isUploading ? null : () => _showAttachmentOptions(),
                  icon: Icon(
                    Icons.add,
                    color: _isUploading
                        ? AppTheme.textSecondary.withOpacity(0.5)
                        : AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isUploading,
                    onChanged: _onTypingChanged,
                    decoration: InputDecoration(
                      hintText: _isUploading
                          ? 'Uploading attachments...'
                          : 'Type a message...',
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                      ),
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
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
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
                    final canSend = hasText && !_isUploading;

                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: canSend
                          ? AppTheme.primary
                          : AppTheme.textSecondary.withOpacity(0.3),
                      child: IconButton(
                        onPressed: canSend ? _sendMessage : null,
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

    // Show divider when date changes (not just time)
    return !_isSameDay(currentMessage.createdAt, previousMessage.createdAt);
  }

  /// Check if two dates are on the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Build status row or typing indicator
  Widget _buildStatusOrTyping(ConversationParticipant? participant) {
    // Watch typing users for this conversation
    final typingParams = TypingUsersParams(
      businessId: widget.conversation.businessId,
      integrationId: widget.conversation.integrationId,
      conversationId: widget.conversation.id,
    );

    final typingUsersAsync = ref.watch(typingUsersProvider(typingParams));

    return typingUsersAsync.when(
      data: (typingUsers) {
        // Show typing indicator if users are typing
        if (typingUsers.isNotEmpty) {
          return Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 12,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  typingUsers.first.displayText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }

        // Otherwise show normal status
        return Row(
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
        );
      },
      loading: () => Row(
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
      error: (_, __) => Row(
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
    );
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
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
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
    } else if (timestamp.year == now.year) {
      // Same year: show "Month Day"
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
      return '${months[timestamp.month - 1]} ${timestamp.day}';
    } else {
      // Different year: show "Month Day, Year"
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
    showModalBottomSheet(
      context: context,
      builder: (context) => AttachmentMenuSheet(
        conversation: widget.conversation,
        onAttachmentSelected: (attachmentType) {
          Navigator.pop(context);
          _handleAttachment(attachmentType);
        },
      ),
    );
  }

  Future<void> _handleAttachment(String attachmentType) async {
    debugPrint('📎 Handling attachment: $attachmentType');

    try {
      switch (attachmentType) {
        case 'camera':
          await _handleCameraAttachment();
          break;
        case 'gallery':
          await _handleGalleryAttachment();
          break;
        case 'video':
          await _handleVideoAttachment();
          break;
        case 'document':
          await _handleDocumentAttachment();
          break;
        case 'location':
          await _handleLocationAttachment();
          break;
        case 'contact':
          await _handleContactAttachment();
          break;
        default:
          _showSnackBar('Attachment type not supported yet');
      }
    } catch (e) {
      debugPrint('❌ Error handling attachment: $e');
      _showSnackBar('Failed to process attachment');
    }
  }

  Future<void> _handleCameraAttachment() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _showSnackBar('Camera permission required');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final croppedFile = await _cropImage(File(image.path));
      if (croppedFile != null) {
        _addAttachment(croppedFile, 'image');
        _showSnackBar('📷 Photo captured and cropped!');
      }
    }
  }

  Future<void> _handleGalleryAttachment() async {
    final permission = await Permission.photos.request();
    if (!permission.isGranted) {
      _showSnackBar('Gallery permission required');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final croppedFile = await _cropImage(File(image.path));
      if (croppedFile != null) {
        _addAttachment(croppedFile, 'image');
        _showSnackBar('🖼️ Image selected and cropped!');
      }
    }
  }

  Future<void> _handleVideoAttachment() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _showSnackBar('Camera permission required');
      return;
    }

    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (video != null) {
      _addAttachment(File(video.path), 'video');
      _showSnackBar('🎥 Video selected!');
    }
  }

  Future<void> _handleDocumentAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      allowedExtensions: null,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        _addAttachment(File(file.path!), 'document');
        _showSnackBar('📁 Document "${file.name}" selected!');
      }
    }
  }

  Future<void> _handleLocationAttachment() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) {
      _showSnackBar('Location permission required');
      return;
    }

    _showSnackBar('📍 Getting your location...');

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _showSnackBar('📍 Location captured! Ready to send.');
      // TODO: Send message with location data
      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      _showSnackBar('Failed to get location');
      debugPrint('❌ Location error: $e');
    }
  }

  Future<void> _handleContactAttachment() async {
    // TODO: Implement contact picker
    _showSnackBar('👤 Contact sharing coming soon!');
    debugPrint('👤 Contact attachment requested');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
    }
    return null;
  }

  // Attachment management methods
  void _addAttachment(File file, String type) {
    setState(() {
      _attachments.add(file);
      _attachmentTypes.add(type);
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _attachmentTypes.removeAt(index);
      _uploadProgress.remove(index);
    });
  }

  void _viewAttachment(int index) {
    // TODO: Implement full-screen attachment viewer
    final file = _attachments[index];
    final type = _attachmentTypes[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.toUpperCase()} Preview'),
        content: Text('File: ${file.path.split('/').last}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Optimistic UI: Send message and show immediately
  /// Handle typing indicator when user types
  ///
  /// Sends typing=true when user starts typing, then resets after 3 seconds of inactivity.
  void _onTypingChanged(String text) {
    // Cancel existing timer
    _typingTimer?.cancel();

    // If user is typing and we haven't sent typing indicator yet
    if (text.trim().isNotEmpty && !_isCurrentlyTyping) {
      _isCurrentlyTyping = true;
      _sendTypingIndicator(true);
    }

    // Set timer to stop typing indicator after 3 seconds of inactivity
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        _sendTypingIndicator(false);
      }
    });
  }

  /// Send typing indicator to Firestore
  Future<void> _sendTypingIndicator(bool isTyping) async {
    try {
      final service = ref.read(typingIndicatorServiceProvider);

      // TODO: Get actual user ID and name from auth
      await service.setTyping(
        businessId: widget.conversation.businessId,
        integrationId: widget.conversation.integrationId,
        conversationId: widget.conversation.id,
        userId: 'current_user', // TODO: Replace with actual user ID
        userName: 'You',
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Error sending typing indicator: $e');
      // Non-critical error - don't show to user
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty && _attachments.isEmpty) return;
    if (_isUploading) return;

    // Generate temporary ID for optimistic message
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Store attachments for upload
    final pendingAttachments = List<File>.from(_attachments);
    final pendingTypes = List<String>.from(_attachmentTypes);

    // Create placeholder attachments with local paths for immediate preview
    final List<MessageAttachment> placeholderAttachments = [];
    for (int i = 0; i < pendingAttachments.length; i++) {
      // Generate thumbnail for images
      String? thumbnailPath;
      if (pendingTypes[i] == 'image') {
        thumbnailPath =
            await _uploadService.generateThumbnail(pendingAttachments[i]);
      }

      placeholderAttachments.add(
        MessageAttachment(
          type: pendingTypes[i],
          url: '', // Empty until uploaded
          filename: pendingAttachments[i].path.split('/').last,
          localPath: pendingAttachments[i].path,
          thumbnailUrl: thumbnailPath,
          isUploading: true,
          uploadProgress: 0.0,
        ),
      );
    }

    // Create optimistic message with placeholder attachments (shown immediately)
    final optimisticMessage = Message(
      id: tempId,
      businessId: widget.conversation.businessId,
      integrationId: widget.conversation.integrationId,
      conversationId: widget.conversation.id,
      platform: widget.conversation.platform,
      type: _attachments.isNotEmpty
          ? (_attachmentTypes.first == 'image'
              ? MessageType.image
              : _attachmentTypes.first == 'video'
                  ? MessageType.video
                  : MessageType.file)
          : MessageType.text,
      content: MessageContent(
        text: text.isNotEmpty ? text : null,
        attachments:
            placeholderAttachments, // Show with local paths immediately
      ),
      sender: MessageSender(
        id: 'current_user', // TODO: Get actual user ID
        name: 'You',
        isCustomer: false,
      ),
      recipient: MessageRecipient(
        id: 'customer',
        name: 'Customer',
      ),
      metadata: MessageMetadata(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        source: 'mobile_app',
        status: MessageStatus.sending, // Optimistic status
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add message optimistically using pagination provider
    ref
        .read(paginatedMessagesProvider(widget.conversation.id).notifier)
        .addOptimisticMessage(optimisticMessage);

    // Stop typing indicator
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _sendTypingIndicator(false);
    }

    // Clear input immediately for better UX
    final messageText = text;

    _messageController.clear();
    setState(() {
      _attachments.clear();
      _attachmentTypes.clear();
      _uploadProgress.clear();
    });

    try {
      List<MessageAttachment> uploadedAttachments = [];

      // Upload attachments if any, with progress updates
      if (pendingAttachments.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });

        for (int i = 0; i < pendingAttachments.length; i++) {
          final attachment = await _uploadService.uploadAttachment(
            file: pendingAttachments[i],
            attachmentType: pendingTypes[i],
            conversationId: widget.conversation.id,
            onProgress: (progress) {
              // Update the message with current upload progress
              final updatedAttachments = List<MessageAttachment>.from(
                optimisticMessage.content.attachments,
              );
              if (i < updatedAttachments.length) {
                updatedAttachments[i] = updatedAttachments[i].copyWith(
                  uploadProgress: progress,
                );

                final updatedMessage = optimisticMessage.copyWith(
                  content: optimisticMessage.content.copyWith(
                    attachments: updatedAttachments,
                  ),
                );

                // Update message in provider with new progress
                ref
                    .read(paginatedMessagesProvider(widget.conversation.id)
                        .notifier)
                    .updateMessage(tempId, updatedMessage);
              }
            },
          );
          uploadedAttachments.add(attachment);

          // Update message to show completed upload for this attachment
          final updatedAttachments = List<MessageAttachment>.from(
            optimisticMessage.content.attachments,
          );
          if (i < updatedAttachments.length) {
            updatedAttachments[i] = attachment.copyWith(
              isUploading: false,
              uploadProgress: 1.0,
            );

            final updatedMessage = optimisticMessage.copyWith(
              content: optimisticMessage.content.copyWith(
                attachments: updatedAttachments,
              ),
            );

            ref
                .read(
                    paginatedMessagesProvider(widget.conversation.id).notifier)
                .updateMessage(tempId, updatedMessage);
          }
        }

        setState(() {
          _isUploading = false;
        });
      }

      // Create final message with confirmed data
      final confirmedMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        businessId: widget.conversation.businessId,
        integrationId: widget.conversation.integrationId,
        conversationId: widget.conversation.id,
        platform: widget.conversation.platform,
        type: uploadedAttachments.isNotEmpty
            ? (uploadedAttachments.first.type == 'image'
                ? MessageType.image
                : uploadedAttachments.first.type == 'video'
                    ? MessageType.video
                    : MessageType.file)
            : MessageType.text,
        content: MessageContent(
          text: messageText.isNotEmpty ? messageText : null,
          attachments: uploadedAttachments,
        ),
        sender: MessageSender(
          id: 'current_user', // TODO: Get actual user ID
          name: 'You',
          isCustomer: false,
        ),
        recipient: MessageRecipient(
          id: 'customer',
          name: 'Customer',
        ),
        metadata: MessageMetadata(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          source: 'mobile_app',
          status: MessageStatus.sent, // Confirmed status
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Send message to backend
      final messagesService = ref.read(messagesServiceProvider);
      final messagesApiService = ref.read(messagesApiServiceProvider);
      await messagesService.sendMessage(
        confirmedMessage,
        apiService: messagesApiService,
      );

      // Update optimistic message with confirmed one
      ref
          .read(paginatedMessagesProvider(widget.conversation.id).notifier)
          .updateMessage(tempId, confirmedMessage);

      debugPrint('✅ Message sent successfully with ID: ${confirmedMessage.id}');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');

      setState(() {
        _isUploading = false;
        _uploadProgress.clear();
      });

      // Update message status to failed
      final failedMessage = optimisticMessage.copyWith(
        metadata: optimisticMessage.metadata.copyWith(
          status: MessageStatus.failed,
        ),
      );

      ref
          .read(paginatedMessagesProvider(widget.conversation.id).notifier)
          .updateMessage(tempId, failedMessage);

      _showSnackBar('Failed to send message. Tap to retry.');
      debugPrint('❌ Send message error: $e');
    }
  }
}

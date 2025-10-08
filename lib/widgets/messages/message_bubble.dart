import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showTimestamp;

  const MessageBubble({
    Key? key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFromCustomer = message.sender.isCustomer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFromCustomer) ...[
            // Customer avatar
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundColor: _getPlatformColor(message.platform),
                child: Text(
                  message.sender.name?.substring(0, 1).toUpperCase() ?? 'U',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
            // Message bubble
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showAvatar && message.sender.name != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        message.sender.name!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: showAvatar
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                    ),
                    child: _buildMessageContent(context, theme),
                  ),
                  if (showTimestamp)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: _buildTimestamp(context, theme),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 50),
          ] else ...[
            // Business message (right aligned)
            const SizedBox(width: 50),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: showAvatar
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                    ),
                    child: _buildMessageContent(context, theme,
                        isFromBusiness: true),
                  ),
                  if (showTimestamp)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: _buildTimestamp(context, theme),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.business,
                  size: 16,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            else
              const SizedBox(width: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, ThemeData theme,
      {bool isFromBusiness = false}) {
    final textColor = isFromBusiness
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message type indicator
          if (message.type != MessageType.text)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _getMessageTypeIcon(message.type),
                    size: 16,
                    color: textColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.type.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

          // Text content
          if (message.content.text != null)
            Text(
              message.content.text!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor,
                height: 1.4,
              ),
            ),

          // Attachments
          if (message.content.attachments.isNotEmpty)
            ...message.content.attachments.map((attachment) =>
                _buildAttachment(context, attachment, textColor)),

          // Location
          if (message.content.location != null)
            _buildLocation(context, message.content.location!, textColor),

          // Contact
          if (message.content.contact != null)
            _buildContact(context, message.content.contact!, textColor),

          // Postback/Quick Reply
          if (message.content.postback != null)
            _buildPostback(context, message.content.postback!, textColor),

          if (message.content.quickReply != null)
            _buildQuickReply(context, message.content.quickReply!, textColor),
        ],
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeago.format(message.createdAt),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
        if (message.metadata.isRead && !message.sender.isCustomer) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all,
            size: 12,
            color: theme.colorScheme.primary,
          ),
        ],
        if (message.metadata.priority != MessagePriority.normal) ...[
          const SizedBox(width: 4),
          Icon(
            _getPriorityIcon(message.metadata.priority),
            size: 12,
            color: _getPriorityColor(message.metadata.priority),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachment(
      BuildContext context, MessageAttachment attachment, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _getAttachmentIcon(attachment.type),
              size: 20,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.filename ?? 'Attachment',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (attachment.size != null)
                    Text(
                      _formatFileSize(attachment.size!),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocation(
      BuildContext context, MessageLocation location, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location.name != null)
                    Text(
                      location.name!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  Text(
                    location.address ??
                        '${location.latitude}, ${location.longitude}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContact(
      BuildContext context, MessageContact contact, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.contact_page,
              size: 20,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contact.name != null)
                    Text(
                      contact.name!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  if (contact.phone != null)
                    Text(
                      contact.phone!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  if (contact.email != null)
                    Text(
                      contact.email!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostback(
      BuildContext context, MessagePostback postback, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.touch_app,
              size: 20,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                postback.title ?? postback.payload,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReply(
      BuildContext context, MessageQuickReply quickReply, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          quickReply.text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
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

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.text:
        return Icons.text_fields;
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.video_file;
      case MessageType.audio:
        return Icons.audio_file;
      case MessageType.file:
        return Icons.attach_file;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.contact:
        return Icons.contact_page;
      case MessageType.postback:
        return Icons.touch_app;
      case MessageType.quickReply:
        return Icons.reply;
      case MessageType.comment:
        return Icons.comment;
      case MessageType.mention:
        return Icons.alternate_email;
      case MessageType.reaction:
        return Icons.favorite;
      case MessageType.story:
        return Icons.auto_stories;
      case MessageType.post:
        return Icons.post_add;
      case MessageType.review:
        return Icons.star;
      case MessageType.lead:
        return Icons.person_add;
      case MessageType.order:
        return Icons.shopping_cart;
      case MessageType.booking:
        return Icons.event;
      case MessageType.system:
        return Icons.info;
    }
  }

  IconData _getAttachmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'document':
      case 'pdf':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  IconData _getPriorityIcon(MessagePriority priority) {
    switch (priority) {
      case MessagePriority.low:
        return Icons.keyboard_arrow_down;
      case MessagePriority.normal:
        return Icons.remove;
      case MessagePriority.high:
        return Icons.keyboard_arrow_up;
      case MessagePriority.urgent:
        return Icons.priority_high;
    }
  }

  Color _getPriorityColor(MessagePriority priority) {
    switch (priority) {
      case MessagePriority.low:
        return Colors.blue;
      case MessagePriority.normal:
        return Colors.grey;
      case MessagePriority.high:
        return Colors.orange;
      case MessagePriority.urgent:
        return Colors.red;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import 'message_status_icon.dart';
import 'video_attachment.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showTimestamp;
  final VoidCallback? onRetry;

  const MessageBubble({
    Key? key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = true,
    this.onRetry,
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
        // Show status icon for business messages (not from customer)
        if (!message.sender.isCustomer) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(theme),
          // Show retry button for failed messages
          if (message.metadata.status == MessageStatus.failed &&
              onRetry != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
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

  Widget _buildStatusIcon(ThemeData theme) {
    return MessageStatusIcon(
      status: message.metadata.status,
      size: 12,
    );
  }

  Widget _buildAttachment(
      BuildContext context, MessageAttachment attachment, Color textColor) {
    if (attachment.type.toLowerCase() == 'image') {
      return _buildImageAttachment(context, attachment, textColor);
    } else if (attachment.type.toLowerCase() == 'video') {
      return _buildVideoAttachment(context, attachment, textColor);
    } else {
      return _buildDocumentAttachment(context, attachment, textColor);
    }
  }

  Widget _buildImageAttachment(
      BuildContext context, MessageAttachment attachment, Color textColor) {
    // Get image URLs from variants (secure upload) or fallback to main URL
    final String? thumbnailUrl = attachment.metadata?['variants']?['thumbnail'];
    final String? mediumUrl = attachment.metadata?['variants']?['medium'];
    final String? fullUrl = attachment.metadata?['variants']?['full'];

    // Use variants if available, otherwise use main URL
    final String displayUrl = mediumUrl ?? attachment.url;
    final String placeholderUrl = thumbnailUrl ?? mediumUrl ?? attachment.url;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: attachment.isUploading
              ? null
              : () => _openAttachment(attachment.copyWith(
                    // Open full-size image
                    url: fullUrl ?? attachment.url,
                  )),
          child: Stack(
            children: [
              // Show local file preview if uploading, otherwise show network image
              if (attachment.isUploading && attachment.localPath != null)
                Image.file(
                  File(attachment.localPath!),
                  height: 200,
                  width: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPlaceholder(),
                )
              else if (displayUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: displayUrl,
                  height: 200,
                  width: 250,
                  fit: BoxFit.cover,
                  // Use thumbnail as placeholder for progressive loading
                  placeholder: (context, url) => placeholderUrl.isNotEmpty &&
                          placeholderUrl != displayUrl
                      ? CachedNetworkImage(
                          imageUrl: placeholderUrl,
                          height: 200,
                          width: 250,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildPlaceholder(),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(isError: true),
                )
              else
                _buildPlaceholder(),

              // Upload progress overlay
              if (attachment.isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              value: attachment.uploadProgress,
                              strokeWidth: 4,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${((attachment.uploadProgress ?? 0.0) * 100).toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Show compression indicator for images with variants
              if (!attachment.isUploading && thumbnailUrl != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 12,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool isError = false}) {
    return Container(
      height: 200,
      width: 250,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.broken_image : Icons.image,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            isError ? 'Failed to load image' : 'Loading...',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoAttachment(
      BuildContext context, MessageAttachment attachment, Color textColor) {
    // Use the new VideoAttachment widget (Task #15)
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: VideoAttachment(
        attachment: attachment,
        width: 250,
      ),
    );
  }

  Widget _buildDocumentAttachment(
      BuildContext context, MessageAttachment attachment, Color textColor) {
    // Extract document metadata
    final String fileName =
        attachment.metadata?['fileName'] ?? attachment.filename ?? 'Document';
    final int? fileSize = attachment.metadata?['fileSize'] ?? attachment.size;
    final String? extension = attachment.metadata?['extension'];
    final int? pages = attachment.metadata?['pages'];

    // Get appropriate icon based on file type
    IconData documentIcon = _getDocumentIcon(extension ?? attachment.type);
    Color iconColor = _getDocumentColor(extension ?? attachment.type);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: GestureDetector(
          onTap: () => _openAttachment(attachment),
          child: Row(
            children: [
              // Document icon with colored background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  documentIcon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filename
                    Text(
                      fileName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // File metadata (size, pages, type)
                    Row(
                      children: [
                        if (fileSize != null) ...[
                          Icon(
                            Icons.storage,
                            size: 12,
                            color: textColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatFileSize(fileSize),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                        if (pages != null) ...[
                          if (fileSize != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style:
                                  TextStyle(color: textColor.withOpacity(0.5)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.description_outlined,
                            size: 12,
                            color: textColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pages ${pages == 1 ? 'page' : 'pages'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (extension != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          extension.toUpperCase().replaceAll('.', ''),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Download/Open icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('pdf')) return Icons.picture_as_pdf;
    if (lowerType.contains('doc')) return Icons.description;
    if (lowerType.contains('xls') || lowerType.contains('sheet'))
      return Icons.table_chart;
    if (lowerType.contains('ppt') || lowerType.contains('presentation'))
      return Icons.slideshow;
    if (lowerType.contains('txt')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _getDocumentColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('pdf')) return Colors.red;
    if (lowerType.contains('doc')) return Colors.blue;
    if (lowerType.contains('xls') || lowerType.contains('sheet'))
      return Colors.green;
    if (lowerType.contains('ppt') || lowerType.contains('presentation'))
      return Colors.orange;
    if (lowerType.contains('txt')) return Colors.grey;
    return Colors.blueGrey;
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

  void _openAttachment(MessageAttachment attachment) async {
    try {
      final uri = Uri.parse(attachment.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }
}

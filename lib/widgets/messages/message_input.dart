import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/message.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Conversation conversation;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.conversation,
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _canSend = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSendButton);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSendButton);
    super.dispose();
  }

  void _updateSendButton() {
    final canSend = widget.controller.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Quick Actions (if applicable for platform)
              if (_shouldShowQuickActions())
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildQuickActions(context, theme),
                ),

              // Input Row
              Row(
                children: [
                  // Attachment Button
                  IconButton(
                    onPressed: () => _showAttachmentMenu(context),
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: 'Attach file',
                  ),

                  // Text Input
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: _isExpanded ? 120 : 56,
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        decoration: InputDecoration(
                          hintText: _getHintText(),
                          hintStyle: GoogleFonts.inter(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.7),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: _isExpanded ? 5 : 1,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          final shouldExpand =
                              text.contains('\n') || text.length > 50;
                          if (shouldExpand != _isExpanded) {
                            setState(() {
                              _isExpanded = shouldExpand;
                            });
                          }
                        },
                        onSubmitted: _canSend ? (text) => _sendMessage() : null,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    child: FloatingActionButton(
                      onPressed: _canSend ? _sendMessage : null,
                      backgroundColor: _canSend
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                      foregroundColor: _canSend
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      elevation: _canSend ? 2 : 0,
                      mini: true,
                      child: Icon(
                        _canSend ? Icons.send : Icons.mic,
                        size: 20,
                      ),
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

  bool _shouldShowQuickActions() {
    // Show quick actions for platforms that support them
    switch (widget.conversation.platform) {
      case MessagePlatform.messenger:
      case MessagePlatform.instagram:
      case MessagePlatform.whatsapp:
        return true;
      default:
        return false;
    }
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickActionChip(
            icon: Icons.thumb_up,
            label: 'Like',
            onTap: () => widget.onSend('👍'),
          ),
          const SizedBox(width: 8),
          _QuickActionChip(
            icon: Icons.schedule,
            label: 'Hours',
            onTap: () => _sendBusinessHours(),
          ),
          const SizedBox(width: 8),
          _QuickActionChip(
            icon: Icons.location_on,
            label: 'Location',
            onTap: () => _sendLocation(),
          ),
          const SizedBox(width: 8),
          _QuickActionChip(
            icon: Icons.phone,
            label: 'Contact',
            onTap: () => _sendContact(),
          ),
          const SizedBox(width: 8),
          _QuickActionChip(
            icon: Icons.help,
            label: 'FAQ',
            onTap: () => _showFAQ(),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (widget.conversation.platform) {
      case MessagePlatform.email:
        return 'Compose your email...';
      case MessagePlatform.sms:
        return 'Type your SMS...';
      case MessagePlatform.whatsapp:
        return 'Type a WhatsApp message...';
      case MessagePlatform.messenger:
        return 'Type a message...';
      case MessagePlatform.instagram:
        return 'Send a message on Instagram...';
      default:
        return 'Type your message...';
    }
  }

  void _sendMessage() {
    if (_canSend) {
      widget.onSend(widget.controller.text.trim());
    }
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => AttachmentMenuSheet(
        conversation: widget.conversation,
        onAttachmentSelected: (attachment) {
          // TODO: Handle attachment
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attachment feature coming soon'),
            ),
          );
        },
      ),
    );
  }

  void _sendBusinessHours() {
    widget.onSend(
      'Our business hours are:\n'
      'Monday - Friday: 9:00 AM - 6:00 PM\n'
      'Saturday: 10:00 AM - 4:00 PM\n'
      'Sunday: Closed\n\n'
      'Feel free to reach out during these times!',
    );
  }

  void _sendLocation() {
    widget.onSend(
      'Visit us at our location:\n'
      '123 Business Street\n'
      'City, State 12345\n\n'
      'We look forward to seeing you!',
    );
  }

  void _sendContact() {
    widget.onSend(
      'Contact us:\n'
      '📞 Phone: (555) 123-4567\n'
      '📧 Email: contact@business.com\n'
      '🌐 Website: www.business.com\n\n'
      'We\'re here to help!',
    );
  }

  void _showFAQ() {
    // TODO: Implement FAQ selection
    widget.onSend(
      'Here are some frequently asked questions:\n\n'
      '1. What are your business hours?\n'
      '2. Where are you located?\n'
      '3. How can I contact you?\n'
      '4. What services do you offer?\n\n'
      'Let me know if you need help with any of these!',
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttachmentMenuSheet extends StatelessWidget {
  final Conversation conversation;
  final Function(String) onAttachmentSelected;

  const AttachmentMenuSheet({
    Key? key,
    required this.conversation,
    required this.onAttachmentSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Attachments',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Attachment options
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _AttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => onAttachmentSelected('camera'),
              ),
              _AttachmentOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => onAttachmentSelected('gallery'),
              ),
              _AttachmentOption(
                icon: Icons.videocam,
                label: 'Video',
                onTap: () => onAttachmentSelected('video'),
              ),
              _AttachmentOption(
                icon: Icons.attach_file,
                label: 'Document',
                onTap: () => onAttachmentSelected('document'),
              ),
              _AttachmentOption(
                icon: Icons.location_on,
                label: 'Location',
                onTap: () => onAttachmentSelected('location'),
              ),
              _AttachmentOption(
                icon: Icons.contact_page,
                label: 'Contact',
                onTap: () => onAttachmentSelected('contact'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

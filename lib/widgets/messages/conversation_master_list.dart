import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../providers/messages_provider.dart';

class ConversationMasterList extends ConsumerWidget {
  final String? selectedChannel;
  final String? selectedConversationId;
  final Function(Conversation) onConversationSelected;
  final bool isCompact;
  final bool skipPlatformFiltering;
  final List<Conversation>? conversations; // NEW: Accept filtered conversations
  final bool showGrouped; // NEW: Show conversations grouped by integration

  const ConversationMasterList({
    Key? key,
    required this.selectedChannel,
    required this.selectedConversationId,
    required this.onConversationSelected,
    this.isCompact = false,
    this.skipPlatformFiltering = false,
    this.conversations, // NEW: Optional filtered conversations
    this.showGrouped = false, // NEW: Default to ungrouped
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print(
        '🔄 ConversationMasterList.build: showGrouped=$showGrouped, conversations=${conversations?.length ?? 'provider'}');

    // Use provided conversations if available, otherwise fetch from provider
    if (conversations != null) {
      final filteredConversations = _filterConversations(conversations!);
      final sortedConversations = _sortConversations(filteredConversations);

      print(
          '📊 Conversations: total=${conversations!.length}, filtered=${filteredConversations.length}, sorted=${sortedConversations.length}');

      if (sortedConversations.isEmpty) {
        print('❌ No conversations to display');
        return _buildEmptyState();
      }

      // Show grouped or ungrouped based on parameter
      if (showGrouped) {
        print('📑 Rendering GROUPED conversations');
        return _buildGroupedConversations(sortedConversations);
      } else {
        print('📋 Rendering UNGROUPED conversations');
        return _buildUngroupedConversations(sortedConversations);
      }
    }

    // Fallback to provider if no conversations provided
    final conversationsAsync = ref.watch(messagesProvider);

    return conversationsAsync.when(
      data: (conversations) {
        final filteredConversations = _filterConversations(conversations);
        final sortedConversations = _sortConversations(filteredConversations);

        if (sortedConversations.isEmpty) {
          return _buildEmptyState();
        }

        // Show grouped or ungrouped based on parameter
        if (showGrouped) {
          return _buildGroupedConversations(sortedConversations);
        } else {
          return _buildUngroupedConversations(sortedConversations);
        }
      },
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) => _buildErrorState(error),
    );
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    print(
        '🔍 Filtering conversations: skipPlatformFiltering=$skipPlatformFiltering, selectedChannel=$selectedChannel');

    // Skip platform filtering if already filtered by integrationId at database level
    if (skipPlatformFiltering) {
      print('   ⏭️ Skipping platform filtering - already filtered at DB level');
      return conversations;
    }

    if (selectedChannel == null) {
      print('   🌐 No channel selected - returning all conversations');
      return conversations;
    }

    final filtered = conversations.where((conversation) {
      return conversation.platform.value.toLowerCase() ==
          selectedChannel?.toLowerCase();
    }).toList();

    print(
        '   🎯 Filtered ${conversations.length} → ${filtered.length} conversations for channel: $selectedChannel');
    return filtered;
  }

  List<Conversation> _sortConversations(List<Conversation> conversations) {
    final sortedList = List<Conversation>.from(conversations);

    // Sort by: pinned first, then unread, then by last message timestamp
    sortedList.sort((a, b) {
      // Pinned conversations first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // Then unread conversations
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;

      // Finally by timestamp (newest first)
      return b.lastMessageAt.compareTo(a.lastMessageAt);
    });

    return sortedList;
  }

  Widget _buildConversationTile(Conversation conversation, bool isSelected) {
    final isUnread = conversation.unreadCount > 0;
    final participant = conversation.participants.isNotEmpty
        ? conversation.participants.first
        : null;

    return Material(
      color:
          isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
      child: InkWell(
        onTap: () {
          print(
              '🖱️ Conversation tile tapped: ${conversation.id}, unreadCount: ${conversation.unreadCount}');
          onConversationSelected(conversation);
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              _buildAvatar(participant, conversation.platform.value),
              SizedBox(width: isCompact ? 8 : 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with name, platform, and timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // Participant name
                              Flexible(
                                child: Text(
                                  participant?.name ?? 'Unknown User',
                                  style: GoogleFonts.inter(
                                    fontSize: isCompact ? 14 : 15,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Platform icon
                              if (!isCompact) ...[
                                const SizedBox(width: 6),
                                _buildPlatformIcon(conversation.platform.value),
                              ],

                              // Pinned icon
                              if (conversation.isPinned) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Timestamp
                        Text(
                          _formatTimestamp(conversation.lastMessageAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isUnread
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontWeight:
                                isUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Last message preview and unread count
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessagePreview ?? 'No messages',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isUnread
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight:
                                  isUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Unread count badge
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Tags (if not compact)
                    if (!isCompact && conversation.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: conversation.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ConversationParticipant? participant, String? platform) {
    final size = isCompact ? 40.0 : 48.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getPlatformColor(platform).withOpacity(0.1),
        border: Border.all(
          color: _getPlatformColor(platform).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: _buildInitialsAvatar(participant?.name ?? 'U', size),
    );
  }

  Widget _buildInitialsAvatar(String name, double size) {
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
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(String platform) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _getPlatformColor(platform).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(
        'assets/icons/${platform.toLowerCase()}.png',
        width: 12,
        height: 12,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              platform.substring(0, 1).toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _getPlatformColor(platform),
              ),
            ),
          );
        },
      ),
    );
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
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'youtube':
        return const Color(0xFFFF0000);
      default:
        return AppTheme.primary;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    } else if (difference.inDays < 365) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[timestamp.month - 1]} ${timestamp.day}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedChannel != null
                  ? 'No conversations for $selectedChannel'
                  : 'Start messaging to see conversations here',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 8,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppTheme.primary.withOpacity(0.1),
        indent: isCompact ? 8 : 72,
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: isCompact ? 40 : 48,
                height: isCompact ? 40 : 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),

              SizedBox(width: isCompact ? 8 : 12),

              // Content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load conversations',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUngroupedConversations(List<Conversation> conversations) {
    print(
        '📋 Building ungrouped conversations for ${conversations.length} total conversations');

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conversations.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppTheme.primary.withOpacity(0.1),
        indent: isCompact ? 8 : 72,
      ),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isSelected = conversation.id == selectedConversationId;
        return _buildConversationTile(conversation, isSelected);
      },
    );
  }

  Widget _buildGroupedConversations(List<Conversation> conversations) {
    print(
        '🏗️ Building grouped conversations for ${conversations.length} total conversations');

    // Group conversations by platform/integration
    final groupedConversations = <String, List<Conversation>>{};

    for (final conversation in conversations) {
      final platformName = conversation.platform.value;
      groupedConversations
          .putIfAbsent(platformName, () => [])
          .add(conversation);
    }

    print('📊 Grouped by platforms: ${groupedConversations.keys.toList()}');
    for (final entry in groupedConversations.entries) {
      print('   ${entry.key}: ${entry.value.length} conversations');
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: groupedConversations.length,
      itemBuilder: (context, index) {
        final platform = groupedConversations.keys.elementAt(index);
        final platformConversations = groupedConversations[platform]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    _getPlatformIcon(platform),
                    size: 20,
                    color: _getPlatformColor(platform),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPlatformName(platform),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(platform).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${platformConversations.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getPlatformColor(platform),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Platform conversations
            ...platformConversations.map((conversation) {
              final isSelected = conversation.id == selectedConversationId;
              return Column(
                children: [
                  _buildConversationTile(conversation, isSelected),
                  if (conversation != platformConversations.last)
                    Divider(
                      height: 1,
                      color: AppTheme.primary.withOpacity(0.1),
                      indent: isCompact ? 8 : 72,
                    ),
                ],
              );
            }).toList(),

            // Spacing between platform groups
            if (index < groupedConversations.length - 1)
              const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      case 'whatsapp':
        return Icons.chat;
      case 'messenger':
        return Icons.message;
      case 'telegram':
        return Icons.telegram;
      case 'twitter':
        return Icons.alternate_email;
      case 'email':
        return Icons.email;
      case 'sms':
        return Icons.sms;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  String _formatPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return 'Instagram';
      case 'facebook':
        return 'Facebook';
      case 'whatsapp':
        return 'WhatsApp';
      case 'messenger':
        return 'Messenger';
      case 'telegram':
        return 'Telegram';
      case 'twitter':
        return 'Twitter';
      case 'email':
        return 'Email';
      case 'sms':
        return 'SMS';
      default:
        return platform.toUpperCase();
    }
  }
}

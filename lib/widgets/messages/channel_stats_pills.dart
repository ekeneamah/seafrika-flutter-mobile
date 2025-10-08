import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vendor_app/models/message.dart';
import '../../config/theme.dart';

class ChannelStatsPills extends StatelessWidget {
  final String? selectedChannel;
  final List<Conversation> conversations;

  const ChannelStatsPills({
    Key? key,
    required this.selectedChannel,
    required this.conversations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stats = _calculateChannelStats();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildStatPill(
          icon: Icons.forum_outlined,
          label: 'Total',
          value: '${stats.total}',
          color: AppTheme.primary,
        ),
        _buildStatPill(
          icon: Icons.mark_chat_unread_outlined,
          label: 'Unread',
          value: '${stats.unread}',
          color: const Color(0xFFFF6B6B),
          highlight: stats.unread > 0,
        ),
        _buildStatPill(
          icon: Icons.schedule_outlined,
          label: 'Today',
          value: '${stats.today}',
          color: const Color(0xFF51CF66),
        ),
        _buildStatPill(
          icon: Icons.push_pin_outlined,
          label: 'Pinned',
          value: '${stats.pinned}',
          color: const Color(0xFFFFD43B),
        ),
      ],
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.15) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? color.withOpacity(0.3) : color.withOpacity(0.2),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ChannelStats _calculateChannelStats() {
    final filteredConversations = selectedChannel != null
        ? conversations
            .where((c) =>
                c.platform.value.toLowerCase() ==
                selectedChannel?.toLowerCase())
            .toList()
        : conversations;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    int unreadCount = 0;
    int todayCount = 0;
    int pinnedCount = 0;

    for (final conversation in filteredConversations) {
      // Count unread conversations
      if (conversation.unreadCount > 0) {
        unreadCount++;
      }

      // Count conversations with messages from today
      if (conversation.lastMessageAt != null) {
        final lastMessageDate = conversation.lastMessageAt;
        if (lastMessageDate.isAfter(todayStart)) {
          todayCount++;
        }
      }

      // Count pinned conversations
      if (conversation.isPinned) {
        pinnedCount++;
      }
    }

    return ChannelStats(
      total: filteredConversations.length,
      unread: unreadCount,
      today: todayCount,
      pinned: pinnedCount,
    );
  }
}

class ChannelStats {
  final int total;
  final int unread;
  final int today;
  final int pinned;

  ChannelStats({
    required this.total,
    required this.unread,
    required this.today,
    required this.pinned,
  });
}

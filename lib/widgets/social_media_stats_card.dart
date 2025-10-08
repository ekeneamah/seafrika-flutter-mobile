import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../providers/social_media_stats_provider.dart';
import '../providers/messages_provider.dart';
import '../services/navigation_service.dart';
import '../config/theme.dart';

class SocialMediaStatsCard extends ConsumerWidget {
  const SocialMediaStatsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(socialMediaStatsProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.05),
            AppTheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.2),
                        AppTheme.secondary.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.message_outlined,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Social Media Messages',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage all your customer conversations',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.earth.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Stats Content
            statsAsyncValue.when(
              data: (stats) => _buildStatsContent(context, stats, ref),
              loading: () => _buildLoadingContent(),
              error: (error, stack) => _buildErrorContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent(
      BuildContext context, SocialMediaStats stats, WidgetRef ref) {
    final activePlatforms = stats.totalCounts.entries
        .where((entry) => entry.value > 0)
        .take(4)
        .toList();

    return Column(
      children: [
        // Overall stats
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Messages',
                stats.totalMessages.toString(),
                Icons.chat_bubble_outline,
                AppTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                'Unread',
                stats.totalUnread.toString(),
                Icons.mark_chat_unread,
                stats.totalUnread > 0 ? Colors.red : AppTheme.earth,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Platform breakdown
        if (activePlatforms.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Platforms',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToMessages(context, ref, null),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: activePlatforms.asMap().entries.map((entry) {
              final index = entry.key;
              final platformEntry = entry.value;
              final platform = platformEntry.key;
              final count = platformEntry.value;
              final unreadCount = stats.unreadCounts[platform] ?? 0;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: index < activePlatforms.length - 1 ? 8 : 0),
                  child: _buildPlatformChip(
                    context,
                    ref,
                    platform,
                    count,
                    unreadCount,
                  ),
                ),
              );
            }).toList(),
          ),
        ] else
          _buildEmptyState(),

        const SizedBox(height: 16),

        // Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateToMessages(context, ref, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Manage Messages',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(
    BuildContext context,
    WidgetRef ref,
    MessagePlatform platform,
    int totalCount,
    int unreadCount,
  ) {
    final platformColor = _getPlatformColor(platform);

    return GestureDetector(
      onTap: () => _navigateToMessages(context, ref, platform),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: platformColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: platformColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Text(
                  platform.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              totalCount.toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: platformColor,
              ),
            ),
            Text(
              platform.displayName,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLoadingStat()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingStat()),
          ],
        ),
        const SizedBox(height: 20),
        _buildLoadingStat(),
      ],
    );
  }

  Widget _buildLoadingStat() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.earthLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load message stats',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.earthLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppTheme.earth,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No active conversations',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.earth,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect your social media accounts to start receiving messages',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.earth.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  void _navigateToMessages(
      BuildContext context, WidgetRef ref, MessagePlatform? platform) {
    // If a specific platform is tapped, set it as selected
    if (platform != null) {
      ref.read(selectedPlatformsProvider.notifier).selectPlatforms({platform});
    }

    NavigationService.navigateToMessages();
  }
}

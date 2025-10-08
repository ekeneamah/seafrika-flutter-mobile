import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/integration.dart';
import '../providers/integration_stats_provider.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class IntegrationsCard extends ConsumerWidget {
  const IntegrationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(integrationStatsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Integrations',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connected platforms',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.primary,
                ),
                onPressed: () {
                  NavigationService.navigateToAddIntegration();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          statsAsyncValue.when(
            data: (stats) => _buildStatsContent(context, stats),
            loading: () => _buildLoadingContent(),
            error: (error, stack) => _buildErrorContent(error),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(BuildContext context, IntegrationStats stats) {
    if (stats.totalIntegrations == 0) {
      return _buildEmptyState();
    }

    // Sort integrations alphabetically by platform name
    final sortedIntegrations = List<Integration>.from(stats.integrations)
      ..sort((a, b) =>
          a.platformName.toLowerCase().compareTo(b.platformName.toLowerCase()));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sortedIntegrations.length,
      itemBuilder: (context, index) {
        final integration = sortedIntegrations[index];
        return _buildIntegrationTile(integration);
      },
    );
  }

  Widget _buildIntegrationTile(Integration integration) {
    return GestureDetector(
      onTap: () {
        print(
            'Tapping integration: ${integration.platformName}, ID: ${integration.id}');
        NavigationService.navigateToIntegrationDashboard(
          integration.id,
          integration.platformName,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getPlatformColor(integration.platformName).withOpacity(0.1),
              _getPlatformColor(integration.platformName).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getPlatformColor(integration.platformName).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Platform icon and menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 8), // For alignment
                Expanded(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getPlatformColor(integration.platformName)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: _buildPlatformIcon(integration.platformName),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: _getPlatformColor(integration.platformName),
                  ),
                  onSelected: (value) => _handleMenuAction(value, integration),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('View'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'messages',
                      child: ListTile(
                        leading: Icon(Icons.message),
                        title: Text('Messages'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'posts',
                      child: ListTile(
                        leading: Icon(Icons.post_add),
                        title: Text('Posts'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Show page name if available, otherwise show platform name
            Text(
              integration.pageName ?? integration.platformName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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

  Widget _buildPlatformIcon(String platformName) {
    String assetPath = 'assets/icons/${platformName.toLowerCase()}.png';

    return Image.asset(
      assetPath,
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          _getPlatformIconData(platformName),
          size: 16,
          color: _getPlatformColor(platformName),
        );
      },
    );
  }

  IconData _getPlatformIconData(String platformName) {
    final platform = platformName.toLowerCase();
    if (platform.contains('whatsapp')) {
      return Icons.chat;
    } else if (platform.contains('instagram')) {
      return Icons.photo_camera;
    } else if (platform.contains('facebook')) {
      return Icons.facebook;
    } else if (platform.contains('twitter') || platform.contains('x')) {
      return Icons.alternate_email;
    } else if (platform.contains('tiktok')) {
      return Icons.music_video;
    } else if (platform.contains('youtube')) {
      return Icons.play_circle;
    } else if (platform.contains('messenger')) {
      return Icons.message;
    } else {
      return Icons.integration_instructions;
    }
  }

  Color _getPlatformColor(String platformName) {
    final platform = platformName.toLowerCase();
    if (platform.contains('whatsapp')) {
      return const Color(0xFF25D366);
    } else if (platform.contains('instagram')) {
      return const Color(0xFFE4405F);
    } else if (platform.contains('facebook')) {
      return const Color(0xFF1877F2);
    } else if (platform.contains('twitter') || platform.contains('x')) {
      return const Color(0xFF1DA1F2);
    } else if (platform.contains('tiktok')) {
      return const Color(0xFF000000);
    } else if (platform.contains('youtube')) {
      return const Color(0xFFFF0000);
    } else if (platform.contains('messenger')) {
      return const Color(0xFF0084FF);
    } else {
      return AppTheme.primary;
    }
  }

  Widget _buildLoadingContent() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorContent(dynamic error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load integrations',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.integration_instructions_outlined,
            size: 48,
            color: AppTheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'No Integrations Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your social media platforms to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              NavigationService.navigateToAddIntegration();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Integration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Integration integration) {
    switch (action) {
      case 'view':
        print('Menu View: ${integration.platformName}, ID: ${integration.id}');
        NavigationService.navigateToIntegrationDashboard(
          integration.id,
          integration.platformName,
        );
        break;
      case 'messages':
        print(
            'Menu Messages: ${integration.platformName}, IntegrationID: ${integration.id}');
        print('BusinessID will be determined by businessContextProvider');
        NavigationService.navigateToMessages(
            platform: integration.platformName, integrationId: integration.id);
        break;
      case 'posts':
        ScaffoldMessenger.of(
          NavigationService.navigatorKey.currentContext!,
        ).showSnackBar(
          SnackBar(
            content: Text(
                'Posts management for ${integration.platformName} coming soon'),
            backgroundColor: AppTheme.primary,
          ),
        );
        break;
    }
  }
}
